import AppKit
import os.log
import SwiftUI

// Legacy OverlayView - replaced by per-app overlay windows
struct OverlayView: View {
    @EnvironmentObject var overlayManager: OverlayManager

    var body: some View {
        Color.clear
            .ignoresSafeArea()
    }
}

struct ElementOverlay: View {
    private static let logger = Logger(subsystem: "boo.pekaboo.inspector", category: "ElementOverlay")

    let element: OverlayManager.UIElement
    let isHovered: Bool
    let isSelected: Bool = false

    var body: some View {
        // Debug: Log element info to understand positioning
        let _ = {
            if self.element.elementID.hasPrefix("B") || self.element.elementID.hasPrefix("C") || self.element.elementID
                .hasPrefix("Peekaboo")
            {
                Self.logger
                    .debug(
                        "Element \(self.element.elementID) (\(self.element.displayName)): frame = \(self.element.frame.debugDescription)")
                Self.logger.debug("  App: \(self.element.appBundleID)")
            }
        }()

        // Convert AX coordinates (top-left origin) to SwiftUI coordinates
        // In a full-screen NSWindow with SwiftUI content:
        // - AX: (0,0) is at top-left of screen
        // - SwiftUI: (0,0) is at top-left of the window content
        // Since our window covers the full screen, we can use AX coordinates directly for X,
        // but need to flip Y because SwiftUI still uses top-down while position() uses bottom-up
        let displayFrame = self.element.frame

        // Create Peekaboo-style indicator instead of full overlay
        ZStack {
            // Top-left corner indicator - offset by half the circle size to position correctly
            Circle()
                .fill(self.element.color)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(self.element.elementID)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white))
                .position(x: displayFrame.minX + 15, y: displayFrame.minY + 15)
                .opacity(self.isHovered ? 1.0 : 0.5)

            // Only show full frame outline when hovered
            if self.isHovered {
                Rectangle()
                    .stroke(self.element.color, lineWidth: 2)
                    .frame(width: displayFrame.width, height: displayFrame.height)
                    .position(x: displayFrame.midX, y: displayFrame.midY)

                // Info bubble
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.element.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.8)))
                .position(x: displayFrame.minX + 40, y: displayFrame.minY + 10)
            }
        }
    }

    private func flipYCoordinate(_ rect: CGRect) -> CGRect {
        // The Accessibility API provides coordinates in screen space with origin at top-left
        // NSScreen also uses origin at bottom-left, but SwiftUI within the window uses top-left
        // Since we're creating full-screen windows, we just need to flip Y relative to screen height

        guard let screen = NSScreen.main else { return rect }

        // In a full-screen window, SwiftUI's coordinate system matches the screen's flipped coordinates
        // So we convert from AX's top-left to SwiftUI's top-left within our full-screen window
        let flippedY = screen.frame.height - rect.origin.y - rect.height

        return CGRect(x: rect.origin.x, y: flippedY, width: rect.width, height: rect.height)
    }
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.window = nsView.window
        }
    }
}
