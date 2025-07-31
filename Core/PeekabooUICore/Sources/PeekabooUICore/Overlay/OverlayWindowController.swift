//
//  OverlayWindowController.swift
//  PeekabooUICore
//
//  Manages transparent overlay windows for UI element visualization
//

import AppKit
import SwiftUI

/// Controller for managing overlay windows
@MainActor
public class OverlayWindowController {
    private var overlayWindows: [NSScreen: NSWindow] = [:]
    private let overlayManager: OverlayManager
    private let preset: ElementStyleProvider
    
    public init(
        overlayManager: OverlayManager,
        preset: ElementStyleProvider = InspectorVisualizationPreset()
    ) {
        self.overlayManager = overlayManager
        self.preset = preset
    }
    
    /// Shows overlay windows on all screens
    public func showOverlays() {
        for screen in NSScreen.screens {
            showOverlay(on: screen)
        }
    }
    
    /// Hides all overlay windows
    public func hideOverlays() {
        for window in overlayWindows.values {
            window.orderOut(nil)
        }
    }
    
    /// Removes all overlay windows
    public func removeOverlays() {
        for window in overlayWindows.values {
            window.close()
        }
        overlayWindows.removeAll()
    }
    
    /// Updates overlay visibility based on manager state
    public func updateVisibility() {
        if overlayManager.isOverlayActive {
            showOverlays()
        } else {
            hideOverlays()
        }
    }
    
    // MARK: - Private Methods
    
    private func showOverlay(on screen: NSScreen) {
        let window = overlayWindows[screen] ?? createOverlayWindow(for: screen)
        
        // Update content
        let overlayView = AllAppsOverlayView(overlayManager: overlayManager, preset: preset)
        window.contentView = NSHostingView(rootView: overlayView)
        
        // Position and show
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        
        overlayWindows[screen] = window
    }
    
    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        // Configure window
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Make window click-through
        window.styleMask.insert(.nonactivatingPanel)
        
        return window
    }
}

// MARK: - Screen Change Monitoring

public extension OverlayWindowController {
    /// Starts monitoring for screen configuration changes
    func startMonitoringScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenChange()
            }
        }
    }
    
    /// Stops monitoring screen changes
    func stopMonitoringScreenChanges() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func handleScreenChange() {
        // Remove windows for screens that no longer exist
        let currentScreens = Set(NSScreen.screens)
        let windowScreens = Set(overlayWindows.keys)
        
        for screen in windowScreens.subtracting(currentScreens) {
            overlayWindows[screen]?.close()
            overlayWindows.removeValue(forKey: screen)
        }
        
        // Update overlay visibility
        if overlayManager.isOverlayActive {
            showOverlays()
        }
    }
}