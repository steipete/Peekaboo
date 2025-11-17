//
//  VisualizerBoundsConverter.swift
//  PeekabooAgentRuntime
//

import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif
import PeekabooAutomation
import PeekabooProtocols

enum VisualizerBoundsConverter {
    /// Convert automation-detected elements into the bounds format expected by the visualizer overlay.
    @MainActor
    static func makeVisualizerElements(
        from elements: [PeekabooAutomation.DetectedElement],
        screenBounds: CGRect) -> [PeekabooProtocols.DetectedElement]
    {
        elements.map { element in
            let convertedBounds = self.convertAccessibilityRect(element.bounds, screenBounds: screenBounds)
            return PeekabooProtocols.DetectedElement(
                id: element.id,
                type: element.type,
                bounds: convertedBounds,
                label: element.label,
                value: element.value,
                isEnabled: element.isEnabled)
        }
    }

    /// Accessibility coordinates use a top-left origin. Translate them into the bottom-left coordinate
    /// system used by CoreGraphics/AppKit so overlays line up with the real window.
    static func convertAccessibilityRect(_ rect: CGRect, screenBounds: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return rect }

        let relativeTop = rect.origin.y - screenBounds.origin.y
        let flippedY = screenBounds.maxY - relativeTop - rect.height

        return CGRect(
            x: rect.origin.x,
            y: flippedY,
            width: rect.width,
            height: rect.height)
    }

    /// Resolve the display bounds we should use for coordinate conversion.
    @MainActor
    static func resolveScreenBounds(windowBounds: CGRect, displayBounds: CGRect?) -> CGRect {
        if let displayBounds {
            return displayBounds
        }

        #if canImport(AppKit)
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(windowBounds) }) {
            return screen.frame
        }
        if let main = NSScreen.main?.frame {
            return main
        }
        #endif

        // Fall back to a synthetic rectangle anchored at the window origin. This keeps overlays stable
        // even on platforms where AppKit isn't available (unit tests, headless runners, etc.).
        return CGRect(
            x: windowBounds.origin.x,
            y: windowBounds.origin.y,
            width: max(windowBounds.width, 1440),
            height: max(windowBounds.height, 900))
    }
}
