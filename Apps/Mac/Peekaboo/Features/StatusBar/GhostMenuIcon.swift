import AppKit
import SwiftUI

/// Creates a ghost-shaped icon for the menu bar
@MainActor
struct GhostMenuIcon {
    static func createIcon(size: CGSize = CGSize(width: 18, height: 18), isActive: Bool = false) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let context = NSGraphicsContext.current!.cgContext

            // Scale to fit the icon size
            let scale = min(rect.width / 20, rect.height / 20)
            context.scaleBy(x: scale, y: scale)

            // Ghost body path
            let ghostPath = NSBezierPath()

            // Start from bottom left
            ghostPath.move(to: CGPoint(x: 3, y: 4))

            // Left wave
            ghostPath.curve(
                to: CGPoint(x: 4, y: 2),
                controlPoint1: CGPoint(x: 3, y: 3),
                controlPoint2: CGPoint(x: 3.5, y: 2))

            // Second wave
            ghostPath.curve(
                to: CGPoint(x: 6, y: 3),
                controlPoint1: CGPoint(x: 4.5, y: 2),
                controlPoint2: CGPoint(x: 5.5, y: 2.5))

            // Third wave
            ghostPath.curve(
                to: CGPoint(x: 8, y: 2),
                controlPoint1: CGPoint(x: 6.5, y: 3),
                controlPoint2: CGPoint(x: 7.5, y: 2))

            // Fourth wave
            ghostPath.curve(
                to: CGPoint(x: 10, y: 3),
                controlPoint1: CGPoint(x: 8.5, y: 2),
                controlPoint2: CGPoint(x: 9.5, y: 2.5))

            // Fifth wave
            ghostPath.curve(
                to: CGPoint(x: 12, y: 2),
                controlPoint1: CGPoint(x: 10.5, y: 3),
                controlPoint2: CGPoint(x: 11.5, y: 2))

            // Sixth wave
            ghostPath.curve(
                to: CGPoint(x: 14, y: 3),
                controlPoint1: CGPoint(x: 12.5, y: 2),
                controlPoint2: CGPoint(x: 13.5, y: 2.5))

            // Seventh wave (right edge)
            ghostPath.curve(
                to: CGPoint(x: 16, y: 2),
                controlPoint1: CGPoint(x: 14.5, y: 3),
                controlPoint2: CGPoint(x: 15.5, y: 2))

            // Final wave to corner
            ghostPath.curve(
                to: CGPoint(x: 17, y: 4),
                controlPoint1: CGPoint(x: 16.5, y: 2),
                controlPoint2: CGPoint(x: 17, y: 3))

            // Right side up
            ghostPath.line(to: CGPoint(x: 17, y: 12))

            // Top right curve
            ghostPath.curve(
                to: CGPoint(x: 10, y: 18),
                controlPoint1: CGPoint(x: 17, y: 16),
                controlPoint2: CGPoint(x: 14, y: 18))

            // Top left curve
            ghostPath.curve(
                to: CGPoint(x: 3, y: 12),
                controlPoint1: CGPoint(x: 6, y: 18),
                controlPoint2: CGPoint(x: 3, y: 16))

            // Close path
            ghostPath.close()

            // Draw the ghost
            if isActive {
                NSColor.controlAccentColor.setFill()
            } else {
                if #available(macOS 14.0, *) {
                    NSColor.labelColor.setFill()
                } else {
                    NSColor.labelColor.setFill()
                }
            }
            ghostPath.fill()

            // Draw eyes
            let leftEyePath = NSBezierPath(ovalIn: NSRect(x: 6, y: 10, width: 2.5, height: 3.5))
            let rightEyePath = NSBezierPath(ovalIn: NSRect(x: 11.5, y: 10, width: 2.5, height: 3.5))

            if isActive {
                NSColor.white.setFill()
            } else {
                NSColor.controlBackgroundColor.setFill()
            }
            leftEyePath.fill()
            rightEyePath.fill()

            // Draw pupils (looking slightly up for a friendly appearance)
            let leftPupilPath = NSBezierPath(ovalIn: NSRect(x: 6.5, y: 11.5, width: 1.5, height: 1.5))
            let rightPupilPath = NSBezierPath(ovalIn: NSRect(x: 12, y: 11.5, width: 1.5, height: 1.5))

            if isActive {
                NSColor.controlAccentColor.setFill()
            } else {
                NSColor.labelColor.setFill()
            }
            leftPupilPath.fill()
            rightPupilPath.fill()

            // Add a subtle mouth if active
            if isActive {
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
}
