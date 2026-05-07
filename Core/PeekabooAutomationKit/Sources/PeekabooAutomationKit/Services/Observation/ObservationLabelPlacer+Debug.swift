import AppKit
import Foundation

extension SmartLabelPlacer {
    /// Creates a debug image showing edge detection results.
    func createDebugVisualization(for rect: NSRect) -> NSImage? {
        let imageRect = self.imageRect(forDrawingRect: rect)
        let result = self.textDetector.analyzeRegion(imageRect, in: self.image)

        let debugImage = NSImage(size: rect.size)
        debugImage.lockFocus()

        let color = if result.hasText {
            NSColor.red.withAlphaComponent(0.5)
        } else {
            NSColor.green.withAlphaComponent(0.5)
        }

        color.setFill()
        NSRect(origin: .zero, size: rect.size).fill()

        let text = String(format: "%.1f%%", result.density * 100)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white,
        ]
        text.draw(at: NSPoint(x: 2, y: 2), withAttributes: attributes)

        debugImage.unlockFocus()

        return debugImage
    }
}
