import SwiftUI
import AppKit

struct AppOverlayView: View {
    let app: OverlayManager.ApplicationInfo
    @ObservedObject var overlayManager: OverlayManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)
                
                // Debug: Show which app's overlay this is
                Text("Overlay for: \(app.name) (\(app.elements.filter { $0.isActionable }.count) elements)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
                    .background(Color.white.opacity(0.9))
                    .padding(8)
                    .position(x: geometry.size.width / 2, y: 30)
                
                // Only show elements for this specific app
                elementOverlays
                windowBoundaries
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
    
    private var elementOverlays: some View {
        Group {
            // Only show overlays for actionable elements to reduce clutter
            ForEach(app.elements.filter { $0.isActionable }) { element in
                let isHovered = overlayManager.hoveredElement?.id == element.id
                
                ElementOverlay(
                    element: element,
                    isHovered: isHovered
                )
                .allowsHitTesting(false)
            }
        }
    }
    
    private var windowBoundaries: some View {
        Group {
            ForEach(app.windows) { window in
                WindowBoundaryOverlay(window: window)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct WindowBoundaryOverlay: View {
    let window: OverlayManager.WindowInfo
    
    var body: some View {
        GeometryReader { geometry in
            let flippedFrame = flipYCoordinate(window.frame)
            
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .frame(width: window.frame.width, height: window.frame.height)
                .position(x: window.frame.midX, y: flippedFrame.midY)
        }
    }
    
    private func flipYCoordinate(_ rect: CGRect) -> CGRect {
        // The Accessibility API uses a coordinate system with origin at top-left of the primary screen
        // SwiftUI NSWindow uses a coordinate system with origin at bottom-left of the primary screen
        // We need to flip the Y coordinate
        
        guard let primaryScreen = NSScreen.main else { return rect }
        let primaryHeight = primaryScreen.frame.height
        
        // Convert from top-left origin to bottom-left origin
        let flippedY = primaryHeight - rect.origin.y - rect.height
        
        return CGRect(x: rect.origin.x, y: flippedY, width: rect.width, height: rect.height)
    }
}