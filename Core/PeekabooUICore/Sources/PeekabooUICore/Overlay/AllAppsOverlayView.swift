//
//  AllAppsOverlayView.swift
//  PeekabooUICore
//
//  Overlay view that shows elements from all applications
//

import AppKit
import Observation
import SwiftUI

public struct AllAppsOverlayView: View {
    @Bindable private var overlayManager: OverlayManager
    let preset: any ElementStyleProvider
    let screenFrame: CGRect
    let primaryScreenFrame: CGRect

    public init(
        overlayManager: OverlayManager,
        preset: any ElementStyleProvider = InspectorVisualizationPreset(),
        screenFrame: CGRect,
        primaryScreenFrame: CGRect)
    {
        self._overlayManager = Bindable(overlayManager)
        self.preset = preset
        self.screenFrame = screenFrame
        self.primaryScreenFrame = primaryScreenFrame
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background to capture mouse events
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)

                // Overlay elements from all applications
                ForEach(self.overlayManager.applications) { app in
                    AppOverlayView(
                        application: app,
                        preset: self.preset,
                        screenFrame: self.screenFrame,
                        primaryScreenFrame: self.primaryScreenFrame)
                }

                if let hoveredElement = overlayManager.hoveredElement {
                    HoverHighlightView(element: hoveredElement)
                        .position(
                            OverlayScreenGeometry.swiftUICenter(
                                for: hoveredElement.frame,
                                on: self.screenFrame,
                                primaryScreen: self.primaryScreenFrame))
                        .allowsHitTesting(false)
                }

                if let selectedElement = overlayManager.selectedElement {
                    SelectionHighlightView(element: selectedElement)
                        .position(
                            OverlayScreenGeometry.swiftUICenter(
                                for: selectedElement.frame,
                                on: self.screenFrame,
                                primaryScreen: self.primaryScreenFrame))
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
                lineWidth: 3)
            .frame(width: self.element.frame.width + 8, height: self.element.frame.height + 8)
            .scaleEffect(self.animateIn ? 1.0 : 1.1)
            .opacity(self.animateIn ? 1.0 : 0)
            .animation(.easeOut(duration: 0.15), value: self.animateIn)
            .onAppear {
                self.animateIn = true
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
                    dashPhase: self.phase))
            .frame(width: self.element.frame.width + 12, height: self.element.frame.height + 12)
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    self.phase = -50
                }
            }
    }
}
