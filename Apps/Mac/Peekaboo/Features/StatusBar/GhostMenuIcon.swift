import AppKit
import SwiftUI

/// Creates a ghost-shaped icon for the menu bar
@MainActor
struct GhostMenuIcon {
    static func createIcon(size: CGSize = CGSize(width: 18, height: 18), isActive: Bool = false) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let context = NSGraphicsContext.current!.cgContext
            let scale = min(rect.width / 20, rect.height / 20)
            context.scaleBy(x: scale, y: scale)

            let ghostPath = self.makeGhostBodyPath()
            self.fillGhost(path: ghostPath, isActive: isActive)
            self.fillEyes(isActive: isActive)
            self.fillPupils(isActive: isActive)
            self.drawMouthIfNeeded(isActive: isActive)

            return true
        }

        image.isTemplate = true
        return image
    }

    /// Creates animation frames for the ghost
    static func createAnimationFrames() -> [NSImage] {
        var frames: [NSImage] = []

        // Create floating animation frames
        for i in 0..<8 {
            let offset = sin(Double(i) / 8.0 * 2 * .pi) * 2
            frames.append(self.createFloatingFrame(yOffset: offset))
        }

        return frames
    }

    private static func createFloatingFrame(yOffset: Double) -> NSImage {
        let size = CGSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let context = NSGraphicsContext.current!.cgContext

            // Apply floating offset
            context.translateBy(x: 0, y: CGFloat(yOffset))

            // Draw the ghost (reuse the main drawing code)
            let ghost = self.createIcon(size: size, isActive: true)
            ghost.draw(in: rect)

            return true
        }

        image.isTemplate = true
        return image
    }

    private static func makeGhostBodyPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 3, y: 4))
        path.curve(
            to: CGPoint(x: 4, y: 2),
            controlPoint1: CGPoint(x: 3, y: 3),
            controlPoint2: CGPoint(x: 3.5, y: 2))
        path.curve(
            to: CGPoint(x: 6, y: 3),
            controlPoint1: CGPoint(x: 4.5, y: 2),
            controlPoint2: CGPoint(x: 5.5, y: 2.5))
        path.curve(
            to: CGPoint(x: 8, y: 2),
            controlPoint1: CGPoint(x: 6.5, y: 3),
            controlPoint2: CGPoint(x: 7.5, y: 2))
        path.curve(
            to: CGPoint(x: 10, y: 3),
            controlPoint1: CGPoint(x: 8.5, y: 2),
            controlPoint2: CGPoint(x: 9.5, y: 2.5))
        path.curve(
            to: CGPoint(x: 12, y: 2),
            controlPoint1: CGPoint(x: 10.5, y: 3),
            controlPoint2: CGPoint(x: 11.5, y: 2))
        path.curve(
            to: CGPoint(x: 14, y: 3),
            controlPoint1: CGPoint(x: 12.5, y: 2),
            controlPoint2: CGPoint(x: 13.5, y: 2.5))
        path.curve(
            to: CGPoint(x: 16, y: 2),
            controlPoint1: CGPoint(x: 14.5, y: 3),
            controlPoint2: CGPoint(x: 15.5, y: 2))
        path.curve(
            to: CGPoint(x: 17, y: 4),
            controlPoint1: CGPoint(x: 16.5, y: 2),
            controlPoint2: CGPoint(x: 17, y: 3))
        path.line(to: CGPoint(x: 17, y: 12))
        path.curve(
            to: CGPoint(x: 10, y: 18),
            controlPoint1: CGPoint(x: 17, y: 16),
            controlPoint2: CGPoint(x: 14, y: 18))
        path.curve(
            to: CGPoint(x: 3, y: 12),
            controlPoint1: CGPoint(x: 6, y: 18),
            controlPoint2: CGPoint(x: 3, y: 16))
        path.close()
        return path
    }

    private static func fillGhost(path: NSBezierPath, isActive: Bool) {
        if isActive {
            NSColor.controlAccentColor.setFill()
        } else {
            NSColor.labelColor.setFill()
        }
        path.fill()
    }

    private static func fillEyes(isActive: Bool) {
        let leftEye = NSBezierPath(ovalIn: NSRect(x: 6, y: 10, width: 2.5, height: 3.5))
        let rightEye = NSBezierPath(ovalIn: NSRect(x: 11.5, y: 10, width: 2.5, height: 3.5))
        (isActive ? NSColor.white : NSColor.controlBackgroundColor).setFill()
        leftEye.fill()
        rightEye.fill()
    }

    private static func fillPupils(isActive: Bool) {
        let leftPupil = NSBezierPath(ovalIn: NSRect(x: 6.5, y: 11.5, width: 1.5, height: 1.5))
        let rightPupil = NSBezierPath(ovalIn: NSRect(x: 12, y: 11.5, width: 1.5, height: 1.5))
        (isActive ? NSColor.controlAccentColor : NSColor.labelColor).setFill()
        leftPupil.fill()
        rightPupil.fill()
    }

    private static func drawMouthIfNeeded(isActive: Bool) {
        guard isActive else { return }

        let mouthPath = NSBezierPath()
        mouthPath.move(to: CGPoint(x: 8, y: 7))
        mouthPath.curve(
            to: CGPoint(x: 12, y: 7),
            controlPoint1: CGPoint(x: 9, y: 6),
            controlPoint2: CGPoint(x: 11, y: 6))
        mouthPath.lineWidth = 0.5
        NSColor.white.setStroke()
        mouthPath.stroke()
    }
}
