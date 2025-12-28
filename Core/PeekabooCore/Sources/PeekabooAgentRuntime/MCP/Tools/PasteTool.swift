import Foundation
import MCP
import os.log
import PeekabooAutomation
import TachikomaMCP
import UniformTypeIdentifiers

/// MCP tool for atomic clipboard+paste+restore.
public struct PasteTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "PasteTool")
    private let context: MCPToolContext

    public let name = "paste"

    public var description: String {
        """
        Atomically set the clipboard, paste (Cmd+V), then restore the previous clipboard.

        Use this when you want fewer steps than:
        - clipboard set
        - hotkey cmd+v
        - clipboard restore

        Targeting:
        - Provide app/pid and/or window_id/window_title/window_index to focus before pasting.

        Payload:
        - text OR filePath/imagePath OR dataBase64+uti (optionally alsoText).
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                // Targeting
                "app": SchemaBuilder.string(description: "Target app name/bundle ID, or 'PID:<n>'."),
                "pid": SchemaBuilder.number(description: "Target process ID (alternative to app)."),
                "window_id": SchemaBuilder.number(description: "Window ID (preferred stable selector)."),
                "window_title": SchemaBuilder.string(description: "Window title (substring match)."),
                "window_index": SchemaBuilder.number(description: "Window index (0-based); requires app/pid."),

                // Payload
                "text": SchemaBuilder.string(description: "Plain text to paste."),
                "filePath": SchemaBuilder
                    .string(description: "Path to a file to paste (file bytes placed on clipboard)."),
                "imagePath": SchemaBuilder.string(description: "Path to an image to paste (alias of filePath)."),
                "dataBase64": SchemaBuilder.string(description: "Base64-encoded payload to paste."),
                "uti": SchemaBuilder.string(description: "UTI for dataBase64, or to force type when pasting a file."),
                "alsoText": SchemaBuilder.string(description: "Optional plain-text companion when pasting binary."),
                "allowLarge": SchemaBuilder.boolean(description: "Allow payloads larger than 10 MB.", default: false),

                // Restore timing
                "restore_delay_ms": SchemaBuilder.number(
                    description: "Delay before restoring the previous clipboard (ms). Default: 150.",
                    minimum: 0,
                    default: 150),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let startTime = Date()

        do {
            let request = try self.makeWriteRequest(arguments: arguments)
            let target = MCPInteractionTarget(
                app: arguments.getString("app"),
                pid: arguments.getInt("pid"),
                windowTitle: arguments.getString("window_title"),
                windowIndex: arguments.getInt("window_index"),
                windowId: arguments.getInt("window_id"))

            _ = try await target.focusIfRequested(windows: self.context.windows)

            let priorClipboard = try? self.context.clipboard.get(prefer: nil)
            let restoreSlot = "paste-\(UUID().uuidString)"

            if priorClipboard != nil {
                try self.context.clipboard.save(slot: restoreSlot)
            }

            let restoreDelayMs = max(0, arguments.getInt("restore_delay_ms") ?? 150)
            var restoreResult: ClipboardReadResult?

            defer {
                if restoreDelayMs > 0 {
                    usleep(useconds_t(restoreDelayMs) * 1000)
                }
                if priorClipboard != nil {
                    restoreResult = try? self.context.clipboard.restore(slot: restoreSlot)
                } else {
                    self.context.clipboard.clear()
                }
            }

            let setResult = try self.context.clipboard.set(request)
            try await self.context.automation.hotkey(keys: "cmd,v", holdDuration: 50)

            let executionTime = Date().timeIntervalSince(startTime)
            let message = "\(AgentDisplayTokens.Status.success) Pasted (Cmd+V) and restored clipboard " +
                "in \(String(format: "%.2f", executionTime))s"

            let pastedObject: [String: Value] = [
                "uti": .string(setResult.utiIdentifier),
                "size": .int(setResult.data.count),
                "textPreview": setResult.textPreview.map(Value.string) ?? .null,
            ]

            let restoredUti: Value = restoreResult.map { .string($0.utiIdentifier) } ?? .null
            let restoredSize: Value = restoreResult.map { .int($0.data.count) } ?? .null
            let restoredObject: [String: Value] = [
                "uti": restoredUti,
                "size": restoredSize,
            ]

            let meta: Value = .object([
                "pasted": .object(pastedObject),
                "previous_clipboard_present": .bool(priorClipboard != nil),
                "restored": .object(restoredObject),
                "restore_delay_ms": .int(restoreDelayMs),
                "execution_time": .double(executionTime),
            ])

            let resolvedWindowTitle = try await target.resolveWindowTitleIfNeeded(windows: self.context.windows)
            let summary = ToolEventSummary(
                targetApp: target.appIdentifier,
                windowTitle: resolvedWindowTitle,
                actionDescription: "Paste",
                notes: setResult.utiIdentifier)

            return ToolResponse(
                content: [.text(message)],
                meta: ToolEventSummary.merge(summary: summary, into: meta))
        } catch let error as MCPInteractionTargetError {
            return ToolResponse.error(error.localizedDescription)
        } catch {
            self.logger.error("Paste failed: \(error.localizedDescription)")
            return ToolResponse.error("Paste failed: \(error.localizedDescription)")
        }
    }

    private func makeWriteRequest(arguments: ToolArguments) throws -> ClipboardWriteRequest {
        if let text = arguments.getString("text"), !text.isEmpty {
            let data = Data(text.utf8)
            return ClipboardWriteRequest(
                representations: ClipboardWriteRequest.textRepresentations(from: data),
                alsoText: nil,
                allowLarge: arguments.getBool("allowLarge") ?? false)
        }

        if let filePath = arguments.getString("filePath") ?? arguments.getString("imagePath") {
            let url = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: url)
            let inferred = UTType(filenameExtension: url.pathExtension) ?? .data
            let forced = arguments.getString("uti").flatMap(UTType.init(_:)) ?? inferred
            return ClipboardWriteRequest(
                representations: [ClipboardRepresentation(utiIdentifier: forced.identifier, data: data)],
                alsoText: arguments.getString("alsoText"),
                allowLarge: arguments.getBool("allowLarge") ?? false)
        }

        if let b64 = arguments.getString("dataBase64"), let utiId = arguments.getString("uti") {
            guard let data = Data(base64Encoded: b64) else {
                throw ClipboardServiceError.writeFailed("Invalid base64 payload.")
            }
            return ClipboardWriteRequest(
                representations: [ClipboardRepresentation(utiIdentifier: utiId, data: data)],
                alsoText: arguments.getString("alsoText"),
                allowLarge: arguments.getBool("allowLarge") ?? false)
        }

        throw ClipboardServiceError.writeFailed(
            "Provide text, filePath/imagePath, or dataBase64+uti.")
    }
}
