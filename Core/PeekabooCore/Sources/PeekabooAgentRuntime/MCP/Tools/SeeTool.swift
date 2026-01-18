import AppKit
import Foundation
import MCP
import os.log
import PeekabooAutomation
import PeekabooFoundation
import PeekabooProtocols
import PeekabooVisualizer

private typealias AutomationDetectedElement = PeekabooAutomation.DetectedElement
import TachikomaMCP

// MARK: - Annotated Screenshot Rendering Helper

private struct AnnotatedScreenshotRenderer {
    let logger: os.Logger

    func render(originalPath: String, elements: [UIElement]) throws -> String {
        guard let originalImage = NSImage(contentsOfFile: originalPath) else {
            self.logger.warning("Failed to load image for annotation, returning original")
            return originalPath
        }

        let annotatedImage = self.makeAnnotatedImage(from: originalImage, elements: elements)
        let annotatedPath = originalPath.replacingOccurrences(of: ".png", with: "_annotated.png")

        guard let pngData = self.makePNGData(from: annotatedImage) else {
            self.logger.warning("Failed to generate PNG data for annotation, returning original")
            return originalPath
        }

        do {
            try pngData.write(to: URL(fileURLWithPath: annotatedPath))
            self.logger.info("Generated annotated screenshot at: \(annotatedPath)")
            return annotatedPath
        } catch {
            self.logger.error("Failed to save annotated screenshot: \(error)")
            return originalPath
        }
    }

    private func makeAnnotatedImage(from originalImage: NSImage, elements: [UIElement]) -> NSImage {
        let annotatedImage = NSImage(size: originalImage.size)
        annotatedImage.lockFocus()
        defer { annotatedImage.unlockFocus() }

        originalImage.draw(
            at: .zero,
            from: NSRect(origin: .zero, size: originalImage.size),
            operation: .copy,
            fraction: 1.0)

        let screenHeight = NSScreen.main?.frame.height ?? originalImage.size.height
        for element in elements {
            guard let rect = self.elementRect(for: element, screenHeight: screenHeight) else { continue }
            self.drawElement(id: element.id, rect: rect)
        }

        return annotatedImage
    }

    private func elementRect(for element: UIElement, screenHeight: CGFloat) -> NSRect? {
        guard element.frame.width > 0, element.frame.height > 0 else { return nil }
        let flippedY = screenHeight - element.frame.minY - element.frame.height
        return NSRect(
            x: element.frame.minX,
            y: flippedY,
            width: element.frame.width,
            height: element.frame.height)
    }

    private func drawElement(id: String, rect: NSRect) {
        self.fillColor.setFill()
        NSBezierPath(rect: rect).fill()

        self.strokeColor.setStroke()
        let borderPath = NSBezierPath(rect: rect)
        borderPath.lineWidth = 2.0
        borderPath.stroke()

        self.drawLabel(id: id, rect: rect)
    }

    private func drawLabel(id: String, rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: self.labelFont,
            .foregroundColor: NSColor.white,
            .backgroundColor: self.textBackgroundColor,
        ]

        let label = id as NSString
        let labelSize = label.size(withAttributes: attributes)

        let labelRect = NSRect(
            x: rect.minX,
            y: rect.maxY + 4,
            width: labelSize.width + 8,
            height: labelSize.height + 4)

        self.textBackgroundColor.setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()

        label.draw(
            in: NSRect(
                x: labelRect.minX + 4,
                y: labelRect.minY + 2,
                width: labelSize.width,
                height: labelSize.height),
            withAttributes: attributes)
    }

    private func makePNGData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private var fillColor: NSColor {
        NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.15)
    }

    private var strokeColor: NSColor {
        NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.9)
    }

    private var labelFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    }

    private var textBackgroundColor: NSColor {
        NSColor(calibratedWhite: 0.1, alpha: 0.85)
    }
}

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
        Peekaboo MCP 3.0.0-beta4 using openai/gpt-5.1
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
            let target = try self.parseCaptureTarget(request.appTarget)
            let screenshotPath = try await self.captureScreenshot(
                target: target,
                path: request.path,
                snapshot: snapshot)
            let (elements, detectedElements) = try await self.detectUIElements(target: target, snapshot: snapshot)
            let annotatedPath = try await self.generateAnnotationIfNeeded(
                annotate: request.annotate,
                screenshotPath: screenshotPath,
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
                target: target)
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

    private func parseCaptureTarget(_ appTarget: String?) throws -> CaptureTarget {
        guard let target = appTarget else {
            return .screen(index: nil)
        }

        // Parse screen:N format
        if target.hasPrefix("screen:") {
            let indexStr = String(target.dropFirst(7))
            if let index = Int(indexStr) {
                return .screen(index: index)
            }
            throw PeekabooError.invalidInput("Invalid screen index: \(indexStr)")
        }

        // Special values
        switch target.lowercased() {
        case "", "screen":
            return .screen(index: nil)
        case "frontmost":
            return .frontmost
        default:
            // Parse PID:N format
            if target.hasPrefix("PID:") {
                let pidStr = String(target.dropFirst(4))
                if let pid = Int32(pidStr) {
                    return .window(app: "PID:\(pid)", index: nil)
                }
                throw PeekabooError.invalidInput("Invalid PID: \(pidStr)")
            }

            // Otherwise treat as app name
            return .window(app: target, index: nil)
        }
    }

    private func captureScreenshot(target: CaptureTarget, path: String?, snapshot: UISnapshot) async throws -> String {
        let screenshotPath = self.makeScreenshotPath(from: path)
        let captureResult = try await self.captureResult(for: target)
        try self.saveCaptureResult(captureResult, to: screenshotPath)
        await snapshot.setScreenshot(path: screenshotPath, metadata: captureResult.metadata)
        return screenshotPath
    }

    private func generateAnnotationIfNeeded(
        annotate: Bool,
        screenshotPath: String,
        elements: [UIElement],
        detectedElements: [AutomationDetectedElement],
        snapshot: UISnapshot) async throws -> String?
    {
        guard annotate else { return nil }
        let annotated = try self.generateAnnotatedScreenshot(originalPath: screenshotPath, elements: elements)
        await self.emitAnnotatedScreenshotVisualizer(
            annotatedPath: annotated,
            detectedElements: detectedElements,
            snapshot: snapshot)
        return annotated
    }

    private func makeScreenshotPath(from userProvidedPath: String?) -> String {
        if let userProvidedPath {
            return userProvidedPath
        }

        let filename = "peekaboo-see-\(Date().timeIntervalSince1970).png"
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .path
    }

    private func captureResult(for target: CaptureTarget) async throws -> CaptureResult {
        switch target {
        case let .screen(index):
            return try await self.context.screenCapture.captureScreen(displayIndex: index)
        case .frontmost:
            return try await self.context.screenCapture.captureFrontmost()
        case let .window(identifier, _):
            try await self.validateWindowsExist(for: identifier)
            return try await self.context.screenCapture.captureWindow(
                appIdentifier: identifier,
                windowIndex: 0)
        case .area:
            throw PeekabooError.invalidInput("Area capture not supported for see tool")
        }
    }

    private func validateWindowsExist(for identifier: String) async throws {
        let windows = try await self.context.windows.listWindows(target: .application(identifier))
        guard !windows.isEmpty else {
            throw PeekabooError.windowNotFound(criteria: "No windows found for application: \(identifier)")
        }
    }

    private func saveCaptureResult(_ result: CaptureResult, to path: String) throws {
        try result.imageData.write(to: URL(fileURLWithPath: path))
    }

    private func detectUIElements(
        target: CaptureTarget,
        snapshot: UISnapshot) async throws -> ([UIElement], [AutomationDetectedElement])
    {
        guard let screenshotPath = await snapshot.screenshotPath else {
            self.logger.warning("No screenshot available for element detection")
            return ([], [])
        }

        let imageData = try Data(contentsOf: URL(fileURLWithPath: screenshotPath))
        let windowContext = try await self.windowContext(for: target)

        let detectionResult = try await self.context.automation.detectElements(
            in: imageData,
            snapshotId: snapshot.id,
            windowContext: windowContext)

        let detectedElements = await MainActor.run { detectionResult.elements.all }
        await self.emitElementDetectionVisualizer(from: detectedElements)
        let elements = self.convertElements(detectedElements)
        self.logger.info("Detected \(elements.count) UI elements")
        await snapshot.setUIElements(elements)
        return (elements, detectedElements)
    }

    private func windowContext(for target: CaptureTarget) async throws -> WindowContext? {
        switch target {
        case .frontmost:
            let appInfo = try await self.context.applications.getFrontmostApplication()
            return WindowContext(applicationName: appInfo.name, windowTitle: nil, windowBounds: nil)
        case let .window(appIdentifier, _):
            let windows = try await self.context.windows.listWindows(target: .application(appIdentifier))
            if let firstWindow = windows.first {
                return WindowContext(
                    applicationName: appIdentifier,
                    windowTitle: firstWindow.title,
                    windowBounds: firstWindow.bounds)
            }
            return WindowContext(applicationName: appIdentifier, windowTitle: nil, windowBounds: nil)
        default:
            return nil
        }
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
                description: nil,
                help: nil,
                roleDescription: nil,
                identifier: nil,
                frame: element.bounds,
                isActionable: element.isEnabled,
                parentId: nil,
                children: [],
                keyboardShortcut: nil)
        }
    }

    private func buildToolResponse(
        snapshot: UISnapshot,
        elements: [UIElement],
        output: ScreenshotOutput,
        target: CaptureTarget) async throws -> ToolResponse
    {
        let finalScreenshot = output.annotatedPath ?? output.screenshotPath
        let summaryText = await buildSummary(
            snapshot: snapshot,
            elements: elements,
            screenshotPath: finalScreenshot,
            target: target)

        var content: [MCP.Tool.Content] = [.text(summaryText)]
        if output.annotate, let annotatedPath = output.annotatedPath {
            let imageData = try Data(contentsOf: URL(fileURLWithPath: annotatedPath))
            content.append(.image(data: imageData.base64EncodedString(), mimeType: "image/png", metadata: nil))
        }

        let baseMeta = self.makeMetadata(snapshot: snapshot, elements: elements)
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

    private func makeMetadata(snapshot: UISnapshot, elements: [UIElement]) -> Value {
        .object([
            "snapshot_id": .string(snapshot.id),
            "element_count": .double(Double(elements.count)),
            "actionable_count": .double(Double(elements.count(where: { $0.isActionable }))),
        ])
    }

    // Removed getRolePrefix - no longer needed after refactoring to use main UIElement struct

    private func generateAnnotatedScreenshot(
        originalPath: String,
        elements: [UIElement]) throws -> String
    {
        try AnnotatedScreenshotRenderer(logger: self.logger).render(
            originalPath: originalPath,
            elements: elements)
    }

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
        target: CaptureTarget) async -> String
    {
        await SeeSummaryBuilder(
            snapshot: snapshot,
            elements: elements,
            screenshotPath: screenshotPath)
            .build()
    }
}

// MARK: - Supporting Types

// Using CaptureTarget from PeekabooServices - no need to redefine
// Note: menubar case is not available in the main CaptureTarget enum

// Using the main UIElement model type - no need to redefine

// MARK: - UI Snapshot Management

private struct SeeRequest {
    let appTarget: String?
    let path: String?
    let snapshotId: String?
    let annotate: Bool

    init(arguments: ToolArguments) {
        self.appTarget = arguments.getString("app_target")
        self.path = arguments.getString("path")
        self.snapshotId = arguments.getString("snapshot")
        self.annotate = arguments.getBool("annotate") ?? false
    }
}

private struct ScreenshotOutput {
    let screenshotPath: String
    let annotatedPath: String?
    let annotate: Bool
}

@MainActor
private struct SeeSummaryBuilder {
    let snapshot: UISnapshot
    let elements: [UIElement]
    let screenshotPath: String

    func build() async -> String {
        var lines = self.headerLines()
        await lines.append(contentsOf: self.metadataLines())
        lines.append("Screenshot: \(self.screenshotPath)")
        lines.append("Elements found: \(self.elements.count)")
        lines.append("")
        lines.append(contentsOf: self.elementSection())
        lines.append("")
        lines.append("Use element IDs (B1, T1, etc.) with click, type, and other interaction commands.")
        return lines.joined(separator: "\n")
    }

    private func headerLines() -> [String] {
        [
            "📸 UI State Captured",
            "Snapshot ID: \(self.snapshot.id)",
        ]
    }

    private func metadataLines() async -> [String] {
        guard let metadata = await self.snapshot.screenshotMetadata else { return [] }
        var lines: [String] = []
        if let appInfo = metadata.applicationInfo {
            lines.append("Application: \(appInfo.name)")
        }
        if let windowInfo = metadata.windowInfo {
            lines.append("Window: \(windowInfo.title)")
        }
        return lines
    }

    private func elementSection() -> [String] {
        let elementsByRole = Dictionary(grouping: self.elements, by: { $0.role })
        var lines = ["UI Elements:"]
        for (role, roleElements) in elementsByRole.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append(self.roleHeader(role: role, elements: roleElements))
            lines.append(contentsOf: roleElements.map(self.describeElement))
        }
        return lines
    }

    private func roleHeader(role: String, elements: [UIElement]) -> String {
        let actionableCount = elements.count(where: { $0.isActionable })
        return "\(role) (\(elements.count) found, \(actionableCount) actionable):"
    }

    private func describeElement(_ element: UIElement) -> String {
        var parts = ["  \(element.id)"]
        if let label = self.primaryLabel(for: element) {
            parts.append("\"\(label)\"")
        }
        parts.append("at (\(Int(element.frame.origin.x)), \(Int(element.frame.origin.y)))")
        if !element.isActionable {
            parts.append("[not actionable]")
        }
        return parts.joined(separator: " - ")
    }

    private func primaryLabel(for element: UIElement) -> String? {
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
