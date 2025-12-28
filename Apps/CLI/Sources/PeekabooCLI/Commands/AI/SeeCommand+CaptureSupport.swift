import AppKit
import AXorcist
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import ScreenCaptureKit

@MainActor
extension SeeCommand {
    func saveScreenshot(_ imageData: Data) throws -> String {
        let outputPath: String

        if let providedPath = path {
            outputPath = NSString(string: providedPath).expandingTildeInPath
        } else {
            let timestamp = Date().timeIntervalSince1970
            let filename = "peekaboo_see_\(Int(timestamp)).png"
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(cliValue: nil)
            outputPath = (defaultPath as NSString).appendingPathComponent(filename)
        }

        let directory = (outputPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        try imageData.write(to: URL(fileURLWithPath: outputPath))
        self.logger.verbose("Saved screenshot to: \(outputPath)")

        return outputPath
    }

    func resolveSeeWindowIndex(appIdentifier: String, titleFragment: String?) async throws -> Int? {
        guard let fragment = titleFragment, !fragment.isEmpty else {
            return nil
        }

        let appInfo = try await self.services.applications.findApplication(identifier: appIdentifier)

        let content = try await AXTimeoutHelper.withTimeout(seconds: 5.0) {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        }

        let appWindows = content.windows.filter { window in
            window.owningApplication?.processID == appInfo.processIdentifier
        }

        guard !appWindows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        if let targetWindowID = self.resolveCGWindowID(
            forPID: appInfo.processIdentifier,
            titleFragment: fragment
        ) {
            if let index = appWindows.firstIndex(where: { Int($0.windowID) == Int(targetWindowID) }) {
                return index
            }
        }

        if let index = appWindows.firstIndex(where: { window in
            (window.title ?? "").localizedCaseInsensitiveContains(fragment)
        }) {
            return index
        }

        throw CaptureError.windowNotFound
    }

    func resolveWindowId(appIdentifier: String, titleFragment: String?) async throws -> Int? {
        guard let fragment = titleFragment, !fragment.isEmpty else {
            return nil
        }

        let windows = try await self.services.windows.listWindows(
            target: .applicationAndTitle(app: appIdentifier, title: fragment)
        )
        return windows.first?.windowID
    }

    // swiftlint:disable function_body_length
    func generateAnnotatedScreenshot(
        snapshotId: String,
        originalPath: String
    ) async throws -> String {
        guard let detectionResult = try await self.services.snapshots.getDetectionResult(snapshotId: snapshotId)
        else {
            self.logger.info("No detection result found for snapshot")
            return originalPath
        }

        let annotatedPath = (originalPath as NSString).deletingPathExtension + "_annotated.png"

        guard let nsImage = NSImage(contentsOfFile: originalPath) else {
            throw CaptureError.fileIOError("Failed to load image from \(originalPath)")
        }

        let imageSize = nsImage.size

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(imageSize.width),
            pixelsHigh: Int(imageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        else {
            throw CaptureError.captureFailure("Failed to create bitmap representation")
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            self.logger.error("Failed to create graphics context")
            throw CaptureError.captureFailure("Failed to create graphics context")
        }
        NSGraphicsContext.current = context
        self.logger.verbose("Graphics context created successfully")

        nsImage.draw(in: NSRect(origin: .zero, size: imageSize))
        self.logger.verbose("Original image drawn")

        let fontSize: CGFloat = 8
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]

        let roleColors: [ElementType: NSColor] = [
            .button: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0),
            .textField: NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0),
            .link: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0),
            .checkbox: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0),
            .slider: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0),
            .menu: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0),
        ]

        let enabledElements = detectionResult.elements.all.filter(\.isEnabled)

        if enabledElements.isEmpty {
            self.logger.info("No enabled elements to annotate. Total elements: \(detectionResult.elements.all.count)")
            print("\(AgentDisplayTokens.Status.warning)  No interactive UI elements found to annotate")
            return originalPath
        }

        self.logger.info(
            "Annotating \(enabledElements.count) enabled elements out of \(detectionResult.elements.all.count) total"
        )
        self.logger.verbose("Image size: \(imageSize)")

        var windowOrigin = CGPoint.zero
        if !detectionResult.elements.all.isEmpty {
            let minX = detectionResult.elements.all.map(\.bounds.minX).min() ?? 0
            let minY = detectionResult.elements.all.map(\.bounds.minY).min() ?? 0
            windowOrigin = CGPoint(x: minX, y: minY)
            self.logger.verbose("Estimated window origin from elements: \(windowOrigin)")
        }

        var elementRects: [(element: DetectedElement, rect: NSRect)] = []
        for element in enabledElements {
            let elementFrame = CGRect(
                x: element.bounds.origin.x - windowOrigin.x,
                y: element.bounds.origin.y - windowOrigin.y,
                width: element.bounds.width,
                height: element.bounds.height
            )

            let rect = NSRect(
                x: elementFrame.origin.x,
                y: imageSize.height - elementFrame.origin.y - elementFrame.height,
                width: elementFrame.width,
                height: elementFrame.height
            )

            elementRects.append((element: element, rect: rect))
        }

        let labelPlacer = SmartLabelPlacer(
            image: nsImage,
            fontSize: fontSize,
            debugMode: self.verbose,
            logger: self.logger
        )

        var labelPositions: [(rect: NSRect, connection: NSPoint?, element: DetectedElement)] = []
        var placedLabels: [(rect: NSRect, element: DetectedElement)] = []
        let allElements: [(element: DetectedElement, rect: NSRect)] = elementRects.map { ($0.element, $0.rect) }

        for (element, rect) in elementRects {
            let drawingDetails = [
                "Drawing element: \(element.id)",
                "type: \(element.type)",
                "label: \(element.label ?? "")",
                "rect: \(rect)",
                "enabled: \(element.isEnabled)",
                "selected: \(String(describing: element.isSelected))",
                "windowOrigin: \(windowOrigin)",
                "elementBounds: \(element.bounds)",
            ]

            for detail in drawingDetails {
                self.logger.verbose(detail)
            }

            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
            color.withAlphaComponent(0.8).setStroke()

            let outlinePath = NSBezierPath(rect: rect)
            outlinePath.lineWidth = 1.5
            outlinePath.stroke()

            let label = element.id
            let labelSize = (label as NSString).size(withAttributes: textAttributes)
            guard let placement = labelPlacer.findBestLabelPosition(
                for: element,
                elementRect: rect,
                labelSize: labelSize,
                existingLabels: placedLabels,
                allElements: allElements
            ) else {
                continue
            }

            labelPositions.append((rect: placement.labelRect, connection: placement.connectionPoint, element: element))
            placedLabels.append((rect: placement.labelRect, element: element))

            if let connectionPoint = placement.connectionPoint {
                let linePath = NSBezierPath()
                linePath.move(to: connectionPoint)
                linePath.line(to: NSPoint(x: rect.midX, y: rect.midY))
                linePath.lineWidth = 0.8
                linePath.stroke()
            }
        }

        for (labelRect, _, element) in labelPositions where labelRect.width > 0 {
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1).fill()

            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
            color.withAlphaComponent(0.8).setStroke()
            let borderPath = NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1)
            borderPath.lineWidth = 0.5
            borderPath.stroke()

            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
            idString.draw(at: NSPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2))
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw CaptureError.captureFailure("Failed to create PNG data")
        }

        try pngData.write(to: URL(fileURLWithPath: annotatedPath))
        self.logger.verbose("Created annotated screenshot: \(annotatedPath)")

        if !self.jsonOutput {
            let interactableElements = detectionResult.elements.all.filter(\.isEnabled)
            print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
        }

        return annotatedPath
    }
    // swiftlint:enable function_body_length

    private func resolveCGWindowID(forPID pid: Int32, titleFragment: String) -> CGWindowID? {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32, ownerPID == pid else { continue }
            let title = info[kCGWindowName as String] as? String ?? ""
            guard title.localizedCaseInsensitiveContains(titleFragment) else { continue }
            if let windowID = info[kCGWindowNumber as String] as? CGWindowID {
                return windowID
            }
        }

        return nil
    }
}
