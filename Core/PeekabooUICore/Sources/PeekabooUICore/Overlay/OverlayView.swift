//
//  OverlayView.swift
//  PeekabooUICore
//
//  Individual element overlay visualization
//

import SwiftUI
import AppKit
import PeekabooCore

public struct OverlayView: View {
    let element: OverlayManager.UIElement
    let preset: ElementStyleProvider
    @State private var isHovered = false
    @State private var animateIn = false
    
    public init(element: OverlayManager.UIElement, preset: ElementStyleProvider = InspectorVisualizationPreset()) {
        self.element = element
        self.preset = preset
    }
    
    public var body: some View {
        let style = preset.style(for: roleToCategory(element.role), 
                                state: elementState)
        
        ZStack(alignment: .topLeading) {
            // Main overlay shape
            overlayShape(style: style)
            
            // Label if enabled
            if preset.showsLabels || isHovered {
                labelView(style: style)
                    .offset(x: 0, y: -28)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: element.frame.width, height: element.frame.height)
        .scaleEffect(animateIn ? 1.0 : 0.95)
        .opacity(animateIn ? 1.0 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                animateIn = true
            }
            
            // Debug logging for troubleshooting
            #if DEBUG
            if element.elementID.hasPrefix("B") || element.elementID.hasPrefix("C") || element.elementID.hasPrefix("Peekaboo") {
                logElementInfo()
            }
            #endif
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var elementState: ElementVisualizationState {
        if !element.isEnabled {
            return .disabled
        } else if isHovered && preset.supportsHoverState {
            return .hovered
        } else {
            return .normal
        }
    }
    
    @ViewBuilder
    private func overlayShape(style: ElementStyle) -> some View {
        switch preset.indicatorStyle {
        case .rectangle:
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(Color(cgColor: style.primaryColor).opacity(style.fillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .strokeBorder(
                            Color(cgColor: style.primaryColor).opacity(style.strokeOpacity),
                            lineWidth: style.strokeWidth
                        )
                )
                .shadow(
                    color: shadowColor(from: style.shadow),
                    radius: style.shadow?.radius ?? 0,
                    x: style.shadow?.offsetX ?? 0,
                    y: style.shadow?.offsetY ?? 0
                )
        case .circle, .custom:
            // Corner indicators
            CornerIndicatorsView(
                style: style,
                size: CGSize(width: element.frame.width, height: element.frame.height)
            )
        }
    }
    
    @ViewBuilder
    private func labelView(style: ElementStyle) -> some View {
        let labelStyle = style.labelStyle
            HStack(spacing: 4) {
                Text(element.elementID)
                    .font(.system(size: labelStyle.fontSize, weight: fontWeight(labelStyle.fontWeight)))
                    .foregroundColor(Color(cgColor: labelStyle.textColor))
                
                if !element.displayName.isEmpty && element.displayName != element.role {
                    Text("•")
                        .foregroundColor(Color(cgColor: labelStyle.textColor).opacity(0.5))
                    
                    Text(element.displayName)
                        .font(.system(size: labelStyle.fontSize - 1))
                        .foregroundColor(Color(cgColor: labelStyle.textColor).opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, labelStyle.padding.horizontal)
            .padding(.vertical, labelStyle.padding.vertical)
            .background(
                labelStyle.backgroundColor.map { Color(cgColor: $0) }?
                    .cornerRadius(4)
            )
    }
    
    private func shadowColor(from shadow: PeekabooCore.ShadowStyle?) -> Color {
        guard let shadow = shadow else { return .clear }
        return Color(cgColor: shadow.color)
    }
    
    private func fontWeight(_ weight: PeekabooCore.LabelStyle.FontWeight) -> Font.Weight {
        switch weight {
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        }
    }
    
    private func roleToCategory(_ role: String) -> ElementCategory {
        switch role {
        case "AXButton", "AXPopUpButton":
            return .button
        case "AXTextField", "AXTextArea":
            return .textInput
        case "AXLink":
            return .link
        case "AXStaticText":
            return .text
        case "AXGroup":
            return .container
        case "AXSlider":
            return .slider
        case "AXCheckBox":
            return .checkbox
        case "AXRadioButton":
            return .radioButton
        case "AXMenu", "AXMenuItem", "AXMenuBar":
            return .menu
        case "AXTable", "AXOutline", "AXScrollArea":
            return .container
        default:
            return .text
        }
    }
    
    #if DEBUG
    private func logElementInfo() {
        print("🔍 Element \(element.elementID) (\(element.displayName)): frame = \(element.frame)")
        print("   App: \(element.appBundleID)")
        print("   Role: \(element.role)")
        print("   Enabled: \(element.isEnabled)")
        print("   Actionable: \(element.isActionable)")
    }
    #endif
}

// MARK: - Corner Indicators View

struct CornerIndicatorsView: View {
    let style: ElementStyle
    let size: CGSize
    
    private let cornerSize: CGFloat = 16
    private let cornerThickness: CGFloat = 3
    
    var body: some View {
        ZStack {
            // Top-left corner
            CornerShape(corner: .topLeft)
                .stroke(Color(cgColor: style.primaryColor), lineWidth: cornerThickness)
                .frame(width: cornerSize, height: cornerSize)
                .position(x: 0, y: 0)
            
            // Top-right corner
            CornerShape(corner: .topRight)
                .stroke(Color(cgColor: style.primaryColor), lineWidth: cornerThickness)
                .frame(width: cornerSize, height: cornerSize)
                .position(x: size.width, y: 0)
            
            // Bottom-left corner
            CornerShape(corner: .bottomLeft)
                .stroke(Color(cgColor: style.primaryColor), lineWidth: cornerThickness)
                .frame(width: cornerSize, height: cornerSize)
                .position(x: 0, y: size.height)
            
            // Bottom-right corner
            CornerShape(corner: .bottomRight)
                .stroke(Color(cgColor: style.primaryColor), lineWidth: cornerThickness)
                .frame(width: cornerSize, height: cornerSize)
                .position(x: size.width, y: size.height)
        }
    }
    
    struct CornerShape: Shape {
        enum Corner {
            case topLeft, topRight, bottomLeft, bottomRight
        }
        
        let corner: Corner
        
        func path(in rect: CGRect) -> SwiftUI.Path {
            var path = SwiftUI.Path()
            
            switch corner {
            case .topLeft:
                path.move(to: CGPoint(x: 0, y: rect.height))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: 0))
            case .topRight:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: 0))
                path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: rect.height))
                path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            case .bottomRight:
                path.move(to: CGPoint(x: 0, y: rect.height))
                path.addLine(to: CGPoint(x: rect.width, y: rect.height))
                path.addLine(to: CGPoint(x: rect.width, y: 0))
            }
            
            return path
        }
    }
}