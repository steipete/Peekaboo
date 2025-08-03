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
    let preset: ElementStyleProvider
    @EnvironmentObject var overlayManager: OverlayManager

    public init(
        application: OverlayManager.ApplicationInfo,
        preset: ElementStyleProvider = InspectorVisualizationPreset())
    {
        self.application = application
        self.preset = preset
    }

    public var body: some View {
        ZStack {
            ForEach(self.application.elements) { element in
                OverlayView(element: element, preset: self.preset)
                    .position(
                        x: element.frame.midX,
                        y: element.frame.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
