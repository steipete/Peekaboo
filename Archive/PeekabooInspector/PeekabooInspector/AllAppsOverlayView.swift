import SwiftUI

struct AllAppsOverlayView: View {
    @ObservedObject var overlayManager: OverlayManager

    private func shouldShowElement(_ element: OverlayManager.UIElement) -> Bool {
        guard element.isActionable else { return false }

        switch self.overlayManager.detailLevel {
        case .essential:
            // Only show buttons, links, text fields
            return [
                "AXButton",
                "AXLink",
                "AXTextField",
                "AXTextArea",
                "AXCheckBox",
                "AXRadioButton",
                "AXPopUpButton",
                "AXComboBox",
                "AXSlider",
                "AXMenuItem",
            ].contains(element.role)
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
            // Debug: Remove tint, window is confirmed visible
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(false)

            // Only show overlays when active
            if self.overlayManager.isOverlayActive {
                // Show overlays for all applications
                ForEach(self.overlayManager.applications) { app in
                    // Show overlays based on detail level
                    ForEach(app.elements.filter { self.shouldShowElement($0) }) { element in
                        let isHovered = self.overlayManager.hoveredElement?.id == element.id

                        ElementOverlay(
                            element: element,
                            isHovered: isHovered)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
