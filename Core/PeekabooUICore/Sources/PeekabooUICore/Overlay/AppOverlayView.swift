//
//  AppOverlayView.swift
//  PeekabooUICore
//
//  Overlay view for a single application's UI elements
//

import AppKit
import SwiftUI

public struct AppOverlayView: View {
    let application: OverlayManager.ApplicationInfo
    let preset: any ElementStyleProvider
    let screenFrame: CGRect
    let primaryScreenFrame: CGRect

    public init(
        application: OverlayManager.ApplicationInfo,
        preset: any ElementStyleProvider = InspectorVisualizationPreset(),
        screenFrame: CGRect,
        primaryScreenFrame: CGRect)
    {
        self.application = application
        self.preset = preset
        self.screenFrame = screenFrame
        self.primaryScreenFrame = primaryScreenFrame
    }

    public var body: some View {
        ZStack {
            ForEach(self.application.elements) { element in
                OverlayView(element: element, preset: self.preset)
                    .position(
                        OverlayScreenGeometry.swiftUICenter(
                            for: element.frame,
                            on: self.screenFrame,
                            primaryScreen: self.primaryScreenFrame))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
