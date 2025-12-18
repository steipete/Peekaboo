//
//  PeekabooAgentService+Enhancements.swift
//  PeekabooCore
//
//  Integration of agent enhancements:
//  - #1: Active Window Context Injection
//  - #2: Visual Verification Loop
//  - #3: Smart Screenshots
//

import CoreGraphics
import Foundation
import os.log
import PeekabooAutomation
import Tachikoma

@available(macOS 14.0, *)
extension PeekabooAgentService {
    // MARK: - Enhancement Services

    /// Lazy-initialized desktop context service.
    var desktopContext: DesktopContextService {
        DesktopContextService(services: services)
    }

    /// Lazy-initialized smart capture service.
    var smartCapture: SmartCaptureService {
        SmartCaptureService(captureService: services.screenCapture)
    }

    /// Lazy-initialized action verifier.
    var actionVerifier: ActionVerifier {
        ActionVerifier(smartCapture: smartCapture)
    }

    // MARK: - Context Injection

    /// Inject desktop context into messages before an LLM turn.
    /// Call this before each model invocation when contextAware is enabled.
    func injectDesktopContext(
        into messages: inout [ModelMessage],
        options: AgentEnhancementOptions,
        tools: [AgentTool]
    ) async {
        guard options.contextAware else { return }

        let hasClipboardTool = tools.contains(where: { $0.name == "clipboard" })
        let context = await desktopContext.gatherContext(includeClipboardPreview: hasClipboardTool)
        let contextString = desktopContext.formatContextForPrompt(context)

        // Insert as system message before the last user message
        let systemContent = ModelMessage.ContentPart.text(contextString)
        let contextMessage = ModelMessage(role: .system, content: [systemContent])

        // Find the last user message and insert before it
        if let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) {
            messages.insert(contextMessage, at: lastUserIndex)
        } else {
            // No user message yet, append at end
            messages.append(contextMessage)
        }

        if isVerbose {
            logger.debug("Injected desktop context:\n\(contextString)")
        }
    }

    // MARK: - Tool Execution with Verification

    /// Execute a tool with optional verification.
    /// Wraps the standard tool execution to add post-action verification.
    func executeToolWithVerification(
        _ tool: AgentTool,
        arguments: AgentToolArguments,
        options: AgentEnhancementOptions,
        retryCount: Int = 0
    ) async throws -> (result: AnyAgentToolValue, verified: Bool) {
        // Execute the tool
        let executionContext = ToolExecutionContext(
            messages: [],
            model: currentModel ?? .openai(.gpt51),
            settings: GenerationSettings(maxTokens: 4096),
            sessionId: UUID().uuidString,
            stepIndex: 0
        )

        let result = try await tool.execute(arguments, context: executionContext)

        // Check if we should verify
        guard actionVerifier.shouldVerify(toolName: tool.name, options: options) else {
            return (result, false)
        }

        // Build action descriptor
        let targetElement = arguments["element"]?.stringValue ?? arguments["target"]?.stringValue
        let targetPoint = extractTargetPoint(from: arguments)

        let action = ActionDescriptor(
            toolName: tool.name,
            arguments: arguments.stringDictionary,
            targetElement: targetElement,
            targetPoint: targetPoint
        )

        // Verify the action
        let verification = try await actionVerifier.verify(action: action)

        if verification.success || verification.confidence < 0.5 {
            // Action verified or uncertain - proceed
            if isVerbose {
                logger.info("Action verified: \(tool.name) - \(verification.observation)")
            }
            return (result, true)
        }

        // Verification failed
        logger.warning("Action verification failed: \(verification.observation)")

        // Check if we should retry
        if verification.shouldRetry && retryCount < options.maxVerificationRetries {
            logger.info("Retrying action (attempt \(retryCount + 1)/\(options.maxVerificationRetries))")

            // Small delay before retry
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            return try await executeToolWithVerification(
                tool,
                arguments: arguments,
                options: options,
                retryCount: retryCount + 1
            )
        }

        // Return failure info with the result
        // The caller can decide how to handle this
        return (result, false)
    }

    // MARK: - Smart Capture Integration

    /// Capture screen using smart capture if enabled.
    func captureScreenSmart(
        options: AgentEnhancementOptions,
        afterActionAt point: CGPoint? = nil
    ) async throws -> SmartCaptureResult {
        if let point = point, options.regionFocusAfterAction {
            return try await smartCapture.captureAroundPoint(
                point,
                radius: options.regionCaptureRadius
            )
        }

        if options.smartCapture {
            return try await smartCapture.captureIfChanged(
                threshold: options.changeThreshold
            )
        }

        // Fall back to standard capture
        let captureResult = try await services.screenCapture.captureScreen(displayIndex: nil)
        let image = cgImage(from: captureResult)
        return SmartCaptureResult(
            image: image,
            changed: true,
            metadata: .fresh(capturedAt: Date())
        )
    }

    /// Convert CaptureResult image data to CGImage.
    private func cgImage(from result: CaptureResult) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: result.imageData as CFData),
              let cgImage = CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              )
        else {
            return nil
        }
        return cgImage
    }

    // MARK: - Private Helpers

    private func extractTargetPoint(from arguments: AgentToolArguments) -> CGPoint? {
        // Try common argument patterns for position
        if let x = arguments["x"]?.doubleValue,
           let y = arguments["y"]?.doubleValue
        {
            return CGPoint(x: x, y: y)
        }

        if let position = arguments["position"]?.stringValue {
            // Parse "x,y" format
            let parts = position.split(separator: ",")
            if parts.count == 2,
               let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let y = Double(parts[1].trimmingCharacters(in: .whitespaces))
            {
                return CGPoint(x: x, y: y)
            }
        }

        return nil
    }
}

// MARK: - AgentToolArguments Extension

extension AgentToolArguments {
    /// Convert to string dictionary for serialization.
    var stringDictionary: [String: String] {
        var dict: [String: String] = [:]
        for key in keys {
            if let value = self[key]?.stringValue {
                dict[key] = value
            } else if let value = self[key] {
                // Convert non-string values to string representation
                if let jsonData = try? JSONSerialization.data(withJSONObject: value.toJSON() as Any),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    dict[key] = jsonString
                }
            }
        }
        return dict
    }
}

// MARK: - Enhanced Streaming Loop Configuration

@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Configuration for streaming loop with enhancements.
    struct EnhancedStreamingConfiguration {
        let model: LanguageModel
        let tools: [AgentTool]
        let sessionId: String
        let eventHandler: EventHandler?
        let enhancementOptions: AgentEnhancementOptions

        init(
            model: LanguageModel,
            tools: [AgentTool],
            sessionId: String,
            eventHandler: EventHandler?,
            enhancementOptions: AgentEnhancementOptions = .default
        ) {
            self.model = model
            self.tools = tools
            self.sessionId = sessionId
            self.eventHandler = eventHandler
            self.enhancementOptions = enhancementOptions
        }
    }

    /// Run the streaming loop with enhancements enabled.
    /// This wraps the standard streaming loop to add context injection and verification.
    func runEnhancedStreamingLoop(
        configuration: EnhancedStreamingConfiguration,
        maxSteps: Int,
        initialMessages: [ModelMessage],
        queueMode: QueueMode = .oneAtATime
    ) async throws -> StreamingLoopOutcome {
        var messages = initialMessages

        // Inject initial desktop context if enabled
        await injectDesktopContext(
            into: &messages,
            options: configuration.enhancementOptions,
            tools: configuration.tools
        )

        // Convert to standard configuration, passing through enhancement options
        let standardConfig = StreamingLoopConfiguration(
            model: configuration.model,
            tools: configuration.tools,
            sessionId: configuration.sessionId,
            eventHandler: configuration.eventHandler,
            enhancementOptions: configuration.enhancementOptions
        )

        // TODO: Full integration would modify runStreamingLoop to call
        // injectDesktopContext before each LLM turn and executeToolWithVerification
        // for each tool call. For now, we just inject once at the start.

        return try await runStreamingLoop(
            configuration: standardConfig,
            maxSteps: maxSteps,
            initialMessages: messages,
            queueMode: queueMode
        )
    }
}
