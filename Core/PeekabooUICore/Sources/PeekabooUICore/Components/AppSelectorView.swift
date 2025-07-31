//
//  AppSelectorView.swift
//  PeekabooUICore
//
//  Application selection UI component
//

import SwiftUI
import AppKit

public struct AppSelectorView: View {
    @ObservedObject var overlayManager: OverlayManager
    
    public init(overlayManager: OverlayManager) {
        self.overlayManager = overlayManager
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Target Applications")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Menu("Detail Level") {
                    Button("Essential (Buttons & Inputs)") {
                        overlayManager.setDetailLevel(.essential)
                    }
                    .disabled(overlayManager.detailLevel == .essential)
                    
                    Button("Moderate (Include Lists & Tables)") {
                        overlayManager.setDetailLevel(.moderate)
                    }
                    .disabled(overlayManager.detailLevel == .moderate)
                    
                    Button("All (Show Everything)") {
                        overlayManager.setDetailLevel(.all)
                    }
                    .disabled(overlayManager.detailLevel == .all)
                }
                .menuStyle(.borderlessButton)
                .padding(.trailing, 8)
                
                Menu {
                    Button("All Applications") {
                        overlayManager.setAppSelectionMode(.all)
                    }
                    .disabled(overlayManager.selectedAppMode == .all)
                    
                    Divider()
                    
                    ForEach(overlayManager.applications) { app in
                        Button(action: {
                            overlayManager.setAppSelectionMode(.single, bundleID: app.bundleIdentifier)
                        }) {
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                }
                                Text(app.name)
                            }
                        }
                        .disabled(overlayManager.selectedAppMode == .single && 
                                 overlayManager.selectedAppBundleID == app.bundleIdentifier)
                    }
                } label: {
                    HStack {
                        if overlayManager.selectedAppMode == .all {
                            Image(systemName: "apps.iphone")
                            Text("All Applications")
                        } else if let selectedID = overlayManager.selectedAppBundleID,
                                  let app = overlayManager.applications.first(where: { $0.bundleIdentifier == selectedID }) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(app.name)
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
            }
            
            if overlayManager.selectedAppMode == .single {
                Text("Inspecting single application")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Inspecting all running applications")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}