import SwiftUI

struct AllAppsOverlayView: View {
    @ObservedObject var overlayManager: OverlayManager
    
    private func shouldShowElement(_ element: OverlayManager.UIElement) -> Bool {
        guard element.isActionable else { return false }
        
        switch overlayManager.detailLevel {
        case .essential:
            // Only show buttons, links, text fields
            return ["AXButton", "AXLink", "AXTextField", "AXTextArea", 
                   "AXCheckBox", "AXRadioButton", "AXPopUpButton", 
                   "AXComboBox", "AXSlider", "AXMenuItem"].contains(element.role)
        case .moderate:
            // Show everything except groups
            return element.role != "AXGroup"
        case .all:
            // Show all actionable elements
            return true
        }
    }
    
    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(false)
            
            // Only show overlays when active
            if overlayManager.isOverlayActive {
                // Show overlays for all applications
                ForEach(overlayManager.applications) { app in
                    // Show overlays based on detail level
                    ForEach(app.elements.filter { shouldShowElement($0) }) { element in
                        let isHovered = overlayManager.hoveredElement?.id == element.id
                        
                        ElementOverlay(
                            element: element,
                            isHovered: isHovered
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}