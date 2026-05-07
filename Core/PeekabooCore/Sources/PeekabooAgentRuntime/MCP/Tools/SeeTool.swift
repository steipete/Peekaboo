import Foundation
import MCP
import os.log
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooFoundation
import PeekabooProtocols
import PeekabooVisualizer

private typealias AutomationDetectedElement = PeekabooAutomation.DetectedElement
import TachikomaMCP

/// MCP tool for capturing UI state and element detection
public struct SeeTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "SeeTool")
    private let context: MCPToolContext

    public let name = "see"

    public var description: String {
        """
        Captures a screenshot of the active UI and generates an element map.

        Returns Peekaboo element IDs (B1 for buttons, T1 for text fields, etc.) that can be
        used with interaction commands and creates/updates a snapshot that tracks UI state.
        \(PeekabooMCPVersion.banner) using openai/gpt-5.1
        and anthropic/claude-sonnet-4.5.
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "app_target": SchemaBuilder.string(
                    description: """
                    Optional. Specifies the capture target (same as image tool).
                    For example:
                    Omit or use an empty string (e.g., '') for all screens.
                    Use 'screen:INDEX' (e.g., 'screen:0') for a specific display.
                    Use 'frontmost' for all windows of the current foreground application.
                    Use 'AppName' (e.g., 'Safari') for all windows of that application.
                    Use 'PID:PROCESS_ID' (e.g., 'PID:663') to target a specific process by its PID.
                    """),
                "path": SchemaBuilder.string(
                    description: """
                    Optional. Path to save the screenshot. If omitted, a temporary file is used.
                    """),
                "snapshot": SchemaBuilder.string(
                    description: """
                    Optional. Snapshot ID for UI automation tracking. A new snapshot is created when absent.
                    """),
                "annotate": SchemaBuilder.boolean(
                    description: """
                    Optional. Generate an annotated screenshot with interaction markers and IDs.
                    """,
                    default: false),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request = SeeRequest(arguments: arguments)

        do {
            let snapshot = try await self.getOrCreateSnapshot(snapshotId: request.snapshotId)
            let target = try ObservationTargetArgument.parse(request.appTarget)
            let observation = try await self.observeDesktop(
                target: target,
                path: request.path,
                annotate: request.annotate,
                snapshot: snapshot)
            let screenshotPath = try await self.registerObservationScreenshot(
                observation,
                snapshot: snapshot)
            let (elements, detectedElements) = try await self.detectUIElements(
                observation: observation,
                snapshot: snapshot)
            let annotatedPath = try await self.generateAnnotationIfNeeded(
                annotate: request.annotate,
                observation: observation,
                elements: elements,
                detectedElements: detectedElements,
                snapshot: snapshot)

            return try await self.buildToolResponse(
                snapshot: snapshot,
                elements: elements,
                output: ScreenshotOutput(
                    screenshotPath: screenshotPath,
                    annotatedPath: annotatedPath,
                    annotate: request.annotate),
                target: target,
                observation: observation)
        } catch {
            self.logger.error("See tool execution failed: \(error.localizedDescription)")
            return ToolResponse.error("Failed to capture UI state: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func getOrCreateSnapshot(snapshotId: String?) async throws -> UISnapshot {
        if let snapshotId {
            // Try to get existing snapshot
            if let existingSnapshot = await UISnapshotManager.shared.getSnapshot(id: snapshotId) {
                return existingSnapshot
            }
        }

        // Create new snapshot
        return await UISnapshotManager.shared.createSnapshot()
    }

    private func observeDesktop(
        target: ObservationTargetArgument,
        path: String?,
        annotate: Bool,
        snapshot: UISnapshot) async throws -> DesktopObservationResult
    {
        try await self.context.desktopObservation.observe(DesktopObservationRequest(
            target: target.observationTarget,
            detection: DesktopDetectionOptions(mode: .accessibility),
            output: DesktopObservationOutputOptions(
                path: path,
                saveRawScreenshot: true,
                saveAnnotatedScreenshot: annotate,
                snapshotID: snapshot.id)))
    }

    private func registerObservationScreenshot(
        _ observation: DesktopObservationResult,
        snapshot: UISnapshot) async throws -> String
    {
        guard let screenshotPath = observation.files.rawScreenshotPath else {
            throw OperationError.captureFailed(reason: "Observation did not produce a screenshot path")
        }
        await snapshot.setScreenshot(path: screenshotPath, metadata: observation.capture.metadata)
        return screenshotPath
    }

    private func generateAnnotationIfNeeded(
        annotate: Bool,
        observation: DesktopObservationResult,
        elements: [UIElement],
        detectedElements: [AutomationDetectedElement],
        snapshot: UISnapshot) async throws -> String?
    {
        guard annotate else { return nil }
        guard let annotated = observation.files.annotatedScreenshotPath else {
            throw OperationError.captureFailed(reason: "Observation did not produce an annotated screenshot path")
        }
        await self.emitAnnotatedScreenshotVisualizer(
            annotatedPath: annotated,
            detectedElements: detectedElements,
            snapshot: snapshot)
        return annotated
    }

    private func detectUIElements(
        observation: DesktopObservationResult,
        snapshot: UISnapshot) async throws -> ([UIElement], [AutomationDetectedElement])
    {
        guard let detectionResult = observation.elements else {
            return ([], [])
        }

        let detectedElements = await MainActor.run { detectionResult.elements.all }
        await self.emitElementDetectionVisualizer(from: detectedElements)
        let elements = self.convertElements(detectedElements)
        self.logger.info("Detected \(elements.count) UI elements")
        await snapshot.setUIElements(elements)
        return (elements, detectedElements)
    }

    private func convertElements(_ detected: [AutomationDetectedElement]) -> [UIElement] {
        detected.map { element in
            UIElement(
                id: element.id,
                elementId: element.id,
                role: element.type.rawValue,
                title: element.label,
                label: element.label,
                value: element.value,
                description: element.attributes["description"],
                help: element.attributes["help"],
                roleDescription: element.attributes["roleDescription"],
                identifier: element.attributes["identifier"],
                frame: element.bounds,
                isActionable: element.isEnabled,
                parentId: nil,
                children: [],
                keyboardShortcut: element.attributes["keyboardShortcut"])
        }
    }

    private func buildToolResponse(
        snapshot: UISnapshot,
        elements: [UIElement],
        output: ScreenshotOutput,
        target: ObservationTargetArgument,
        observation: DesktopObservationResult) async throws -> ToolResponse
    {
        let finalScreenshot = output.annotatedPath ?? output.screenshotPath
        let summaryText = await buildSummary(
            snapshot: snapshot,
            elements: elements,
            screenshotPath: finalScreenshot,
            target: target)

        var content: [MCP.Tool.Content] = [.text(text: summaryText, annotations: nil, _meta: nil)]
        if output.annotate, let annotatedPath = output.annotatedPath {
            let imageData = try Data(contentsOf: URL(fileURLWithPath: annotatedPath))
            content.append(.image(
                data: imageData.base64EncodedString(),
                mimeType: "image/png",
                annotations: nil,
                _meta: nil))
        }

        let baseMeta = self.makeMetadata(
            snapshot: snapshot,
            elements: elements,
            observation: observation)
        var summary = ToolEventSummary(
            targetApp: snapshot.applicationName,
            windowTitle: snapshot.windowTitle,
            actionDescription: "See",
            notes: String(describing: target))
        summary.captureApp = snapshot.applicationName
        summary.captureWindow = snapshot.windowTitle

        let mergedMeta = ToolEventSummary.merge(summary: summary, into: baseMeta)
        return ToolResponse(content: content, meta: mergedMeta)
    }

    private func makeMetadata(
        snapshot: UISnapshot,
        elements: [UIElement],
        observation: DesktopObservationResult) -> Value
    {
        ObservationDiagnosticsMetadata.merge(observation, into: .object([
            "snapshot_id": .string(snapshot.id),
            "element_count": .double(Double(elements.count)),
            "actionable_count": .double(Double(elements.count(where: { $0.isActionable }))),
        ]))
    }

    // Removed getRolePrefix - no longer needed after refactoring to use main UIElement struct

    private func emitElementDetectionVisualizer(from detected: [AutomationDetectedElement]) async {
        guard !detected.isEmpty else { return }
        let map = Dictionary(uniqueKeysWithValues: detected.map { ($0.id, $0.bounds) })
        _ = await VisualizationClient.shared.showElementDetection(elements: map)
    }

    @MainActor
    private func emitAnnotatedScreenshotVisualizer(
        annotatedPath: String,
        detectedElements: [AutomationDetectedElement],
        snapshot: UISnapshot) async
    {
        guard !detectedElements.isEmpty else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: annotatedPath)) else { return }
        let metadata = await snapshot.screenshotMetadata
        let windowBounds = metadata?.windowInfo?.bounds
            ?? metadata?.displayInfo?.bounds
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screenBounds = VisualizerBoundsConverter.resolveScreenBounds(
            windowBounds: windowBounds,
            displayBounds: metadata?.displayInfo?.bounds)
        let protocolElements = VisualizerBoundsConverter.makeVisualizerElements(
            from: detectedElements,
            screenBounds: screenBounds)
        _ = await VisualizationClient.shared.showAnnotatedScreenshot(
            imageData: data,
            elements: protocolElements,
            windowBounds: windowBounds)
    }

    @MainActor
    private func buildSummary(
        snapshot: UISnapshot,
        elements: [UIElement],
        screenshotPath: String,
        target _: ObservationTargetArgument) async -> String
    {
        await SeeSummaryBuilder(
            snapshot: snapshot,
            elements: elements,
            screenshotPath: screenshotPath)
            .build()
    }
}

struct SeeElementTextFormatter {
    static func describe(_ element: UIElement) -> String {
        var parts = ["  \(element.id)"]
        if let label = self.primaryLabel(for: element) {
            parts.append("\"\(label)\"")
        }
        let sizeText = "size \(Int(element.frame.width))×\(Int(element.frame.height))"
        parts
            .append(
                "at (\(Int(element.frame.origin.x)), \(Int(element.frame.origin.y))) \(sizeText)")
        if let value = element.value, element.title != nil || element.label != nil {
            parts.append("value: \"\(value)\"")
        }
        if let desc = element.description, !desc.isEmpty {
            parts.append("desc: \"\(desc)\"")
        }
        if let help = element.help, !help.isEmpty {
            parts.append("help: \"\(help)\"")
        }
        if let shortcut = element.keyboardShortcut, !shortcut.isEmpty {
            parts.append("shortcut: \(shortcut)")
        }
        if let identifier = element.identifier, !identifier.isEmpty {
            parts.append("identifier: \(identifier)")
        }
        if !element.isActionable {
            parts.append("[not actionable]")
        }
        return parts.joined(separator: " - ")
    }

    static func primaryLabel(for element: UIElement) -> String? {
        if let title = element.title { return title }
        if let label = element.label { return label }
        if let value = element.value { return "value: \(value)" }
        return nil
    }
}

actor UISnapshot {
    let id: String
    private(set) var screenshotPath: String?
    private(set) var screenshotMetadata: CaptureMetadata?
    private(set) var uiElements: [UIElement] = []
    private(set) var createdAt: Date
    private(set) var lastAccessedAt: Date
    private(set) nonisolated(unsafe) var cachedApplicationName: String?
    private(set) nonisolated(unsafe) var cachedWindowTitle: String?

    init() {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }

    func setScreenshot(path: String, metadata: CaptureMetadata) {
        self.screenshotPath = path
        self.screenshotMetadata = metadata
        self.cachedApplicationName = metadata.applicationInfo?.name
        self.cachedWindowTitle = metadata.windowInfo?.title
        self.lastAccessedAt = Date()
    }

    func setUIElements(_ elements: [UIElement]) {
        self.uiElements = elements
        self.lastAccessedAt = Date()
    }

    func getElement(byId id: String) -> UIElement? {
        self.uiElements.first { $0.id == id }
    }

    nonisolated var applicationName: String? {
        self.cachedApplicationName
    }

    nonisolated var windowTitle: String? {
        self.cachedWindowTitle
    }
}

actor UISnapshotManager {
    static let shared = UISnapshotManager()

    private var snapshots: [String: UISnapshot] = [:]
    private var orderedSnapshotIds: [String] = []

    private init() {}

    func createSnapshot() -> UISnapshot {
        let snapshot = UISnapshot()
        self.snapshots[snapshot.id] = snapshot
        self.orderedSnapshotIds.append(snapshot.id)
        return snapshot
    }

    func getSnapshot(id: String?) -> UISnapshot? {
        if let id {
            return self.snapshots[id]
        }
        if let mostRecentSnapshotId = self.orderedSnapshotIds.last {
            return self.snapshots[mostRecentSnapshotId]
        }
        return nil
    }

    func removeSnapshot(id: String) {
        self.snapshots.removeValue(forKey: id)
        self.orderedSnapshotIds.removeAll(where: { $0 == id })
    }

    func cleanupOldSnapshots(olderThan timeInterval: TimeInterval = 3600) async {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        var newSnapshots: [String: UISnapshot] = [:]
        for (id, snapshot) in self.snapshots {
            let lastAccessed = await snapshot.lastAccessedAt
            guard lastAccessed > cutoffDate else { continue }
            newSnapshots[id] = snapshot
        }
        self.snapshots = newSnapshots
    }
}
