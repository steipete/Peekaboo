//
//  AllAppsOverlayView.swift
//  PeekabooUICore
//
//  Overlay view that shows elements from all applications
//

import SwiftUI
import AppKit

public struct AllAppsOverlayView: View {
    @ObservedObject var overlayManager: OverlayManager
    let preset: ElementStyleProvider
    
    public init(
        overlayManager: OverlayManager,
        preset: ElementStyleProvider = InspectorVisualizationPreset()
    ) {
        self.overlayManager = overlayManager
        self.preset = preset
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background to capture mouse events
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)
                
                // Overlay elements from all applications
                ForEach(overlayManager.applications) { app in
                    AppOverlayView(application: app, preset: preset)
                        .environmentObject(overlayManager)
                }
                
                // Hover highlight
                if let hoveredElement = overlayManager.hoveredElement {
                    HoverHighlightView(element: hoveredElement)
                        .position(
                            x: hoveredElement.frame.midX,
                            y: hoveredElement.frame.midY
                        )
                        .allowsHitTesting(false)
                }
                
                // Selection highlight
                if let selectedElement = overlayManager.selectedElement {
                    SelectionHighlightView(element: selectedElement)
                        .position(
                            x: selectedElement.frame.midX,
                            y: selectedElement.frame.midY
                        )
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Highlight Views

struct HoverHighlightView: View {
    let element: OverlayManager.UIElement
    @State private var animateIn = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                Color.accentColor,
                lineWidth: 3
            )
            .frame(width: element.frame.width + 8, height: element.frame.height + 8)
            .scaleEffect(animateIn ? 1.0 : 1.1)
            .opacity(animateIn ? 1.0 : 0)
            .animation(.easeOut(duration: 0.15), value: animateIn)
            .onAppear {
                animateIn = true
            }
    }
}

struct SelectionHighlightView: View {
    let element: OverlayManager.UIElement
    @State private var phase: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                Color.accentColor,
                style: StrokeStyle(
                    lineWidth: 3,
                    dash: [10, 5],
                    dashPhase: phase
                )
            )
            .frame(width: element.frame.width + 12, height: element.frame.height + 12)
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    phase = -50
                }
            }
    }
}