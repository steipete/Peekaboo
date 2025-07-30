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
    private static let logger = Logger(subsystem: "boo.peekaboo.inspector", category: "ElementOverlay")

    let element: OverlayManager.UIElement
    let isHovered: Bool
    let isSelected: Bool = false
    
    // Use local visualization system
    private let styleProvider = InspectorStyleProvider()
    private let coordinateTransformer = CoordinateTransformer()
    private let idGenerator = ElementIDGenerator.shared

    var body: some View {
        // Debug: Log element info to understand positioning
        _ = {
            if self.element.elementID.hasPrefix("B") || self.element.elementID.hasPrefix("C") || self.element.elementID
                .hasPrefix("Peekaboo")
            {
                Self.logger
                    .debug(
                        "Element \(self.element.elementID) (\(self.element.displayName)): frame = \(self.element.frame.debugDescription)")
                Self.logger.debug("  App: \(self.element.appBundleID)")
            }
        }()

        // Get main screen size for coordinate transformation
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        
        // Transform coordinates
        let transformedFrame = coordinateTransformer.transform(
            self.element.frame,
            from: .screen,
            to: .view(screenSize)
        )
        
        // Convert UIElement to visualization style
        let category = elementCategoryFromRole(self.element.role)
        let elementState: ElementVisualizationState = self.element.isEnabled ? (self.isHovered ? .hover : .normal) : .disabled
        let style = styleProvider.style(for: category, state: elementState)
        
        // Convert CGColor to SwiftUI Color
        let primaryColor = Color(cgColor: style.primaryColor)

        // Create Peekaboo-style indicator instead of full overlay
        ZStack {
            // Corner indicator with ID label
            if let labelStyle = style.labelStyle {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(self.element.elementID)
                            .font(.system(size: labelStyle.fontSize, weight: labelStyle.fontWeight == .bold ? .bold : .regular))
                            .foregroundColor(Color(cgColor: labelStyle.textColor))
                    )
                    .position(x: transformedFrame.minX + 15, y: transformedFrame.minY + 15)
                    .opacity(style.fillOpacity * 5) // Multiply to make it more visible
            }

            // Only show full frame outline when hovered
            if self.isHovered {
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(primaryColor, lineWidth: style.strokeWidth)
                    .frame(width: transformedFrame.width, height: transformedFrame.height)
                    .position(x: transformedFrame.midX, y: transformedFrame.midY)
                    .opacity(style.strokeOpacity)

                // Info bubble with enhanced styling
                if let labelStyle = style.labelStyle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(self.element.displayName)
                            .font(.system(size: labelStyle.fontSize))
                            .foregroundColor(Color(cgColor: labelStyle.textColor))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, labelStyle.padding.horizontal)
                    .padding(.vertical, labelStyle.padding.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(cgColor: labelStyle.backgroundColor ?? .black).opacity(0.8))
                    )
                    .if(style.shadow != nil) { view in
                        view.shadow(
                            color: Color(cgColor: style.shadow!.color).opacity(Double(style.shadow!.color.alpha)),
                            radius: style.shadow!.radius,
                            x: style.shadow!.offsetX,
                            y: style.shadow!.offsetY
                        )
                    }
                    .position(x: transformedFrame.minX + 40, y: transformedFrame.minY + 10)
                }
            }
        }
    }
    
    /// Convert role to ElementCategory
    private func elementCategoryFromRole(_ role: String) -> ElementCategory {
        switch role {
        case "AXButton", "AXPopUpButton":
            return .button
        case "AXTextField", "AXTextArea":
            return .textField
        case "AXLink":
            return .link
        case "AXStaticText":
            return .staticText
        case "AXGroup":
            return .group
        case "AXSlider":
            return .slider
        case "AXCheckBox":
            return .checkbox
        case "AXRadioButton":
            return .radioButton
        case "AXMenuItem":
            return .menu
        case "AXComboBox":
            return .popUpButton
        case "AXRow", "AXCell", "AXOutline", "AXList", "AXTable":
            return .tableView
        default:
            return .other
        }
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
