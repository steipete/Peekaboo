//
//  InspectorView.swift
//  PeekabooUICore
//
//  Main Inspector UI component
//

import AppKit
import SwiftUI
import PeekabooCore

/// Configuration for the Inspector view
public struct InspectorConfiguration {
    public var showPermissionAlert: Bool = true
    public var enableOverlay: Bool = true
    public var defaultDetailLevel: OverlayManager.DetailLevel = .moderate
    
    public init() {}
}

/// Main Inspector view for UI element inspection
public struct InspectorView: View {
    @StateObject private var overlayManager = OverlayManager()
    @State private var showPermissionAlert = false
    @State private var permissionStatus: PermissionStatus = .checking
    @State private var permissionCheckTimer: Timer?
    
    private let configuration: InspectorConfiguration
    
    public enum PermissionStatus {
        case checking
        case granted
        case denied
    }
    
    public init(configuration: InspectorConfiguration = InspectorConfiguration()) {
        self.configuration = configuration
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if permissionStatus == .denied {
                PermissionDeniedView()
            } else if permissionStatus == .checking {
                ProgressView("Checking permissions...")
                    .padding()
            } else {
                mainContent
            }
        }
        .frame(width: 450, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .environmentObject(overlayManager)
        .onAppear {
            startPermissionMonitoring()
            if configuration.enableOverlay {
                openOverlayWindow()
            }
        }
        .onDisappear {
            stopPermissionMonitoring()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peekaboo Inspector")
                        .font(.headline)
                    Text(overlayManager.applications.isEmpty ? 
                         "Hover over UI elements to inspect" :
                         "Monitoring \(overlayManager.applications.count) app\(overlayManager.applications.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("Overlay", isOn: $overlayManager.isOverlayActive)
                    .toggleStyle(.switch)
            }
            .padding()
            
            Divider()
            
            AppSelectorView(overlayManager: overlayManager)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let hoveredElement = overlayManager.hoveredElement {
                    ElementDetailsView(element: hoveredElement)
                        .environmentObject(overlayManager)
                } else {
                    Text("Hover over an element to see details")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
                Divider()
                
                AllElementsView(overlayManager: overlayManager)
            }
            .padding()
        }
    }
    
    private func checkPermissions(prompt: Bool = false) {
        let accessEnabled: Bool
        if prompt {
            let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
            accessEnabled = AXIsProcessTrustedWithOptions(options)
        } else {
            accessEnabled = AXIsProcessTrusted()
        }
        
        let newStatus: PermissionStatus = accessEnabled ? .granted : .denied
        
        // Only update if status changed
        if permissionStatus != newStatus {
            withAnimation {
                permissionStatus = newStatus
            }
            
            // If granted, refresh elements immediately
            if newStatus == .granted {
                overlayManager.refreshAllApplications()
            }
        }
    }
    
    private func startPermissionMonitoring() {
        // Initial check with prompt
        checkPermissions(prompt: configuration.showPermissionAlert)
        
        // Start periodic checking without prompt
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                checkPermissions(prompt: false)
            }
        }
    }
    
    private func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    private func openOverlayWindow() {
        // This would be implemented by the host application
        // as it needs to manage actual window creation
    }
}