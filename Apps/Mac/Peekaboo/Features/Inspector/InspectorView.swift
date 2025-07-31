//
//  InspectorView.swift
//  Peekaboo
//
//  Temporarily simplified Inspector to diagnose touch interaction issues

import AppKit
import PeekabooCore
import PeekabooUICore
import SwiftUI

struct InspectorView: View {
    @Environment(Permissions.self) private var permissions
    @State private var testCounter = 0
    
    var body: some View {
        // Completely bypass PeekabooUICore.InspectorView to test if that's the issue
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peekaboo Inspector (Debug Mode)")
                        .font(.headline)
                    Text("Testing window interactivity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Add a close button to test interaction
                Button("Close") {
                    NSApp.keyWindow?.close()
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main content area with test controls
            ScrollView {
                VStack(spacing: 20) {
                    Text("Window Interaction Test")
                        .font(.title2)
                        .padding(.top)
                    
                    // Test button
                    Button("Click Me - Counter: \(testCounter)") {
                        testCounter += 1
                        print("Button clicked! Counter: \(testCounter)")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Text field to test keyboard input
                    TextField("Type here to test keyboard input", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                    
                    // Slider to test dragging
                    VStack {
                        Text("Drag slider to test mouse tracking:")
                        Slider(value: .constant(0.5), in: 0...1)
                            .frame(width: 300)
                    }
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Permission status
                    VStack(spacing: 10) {
                        Text("Accessibility Status:")
                            .font(.headline)
                        
                        Text(permissions.accessibilityStatus.rawValue)
                            .foregroundColor(permissions.accessibilityStatus == .authorized ? .green : .orange)
                        
                        if permissions.accessibilityStatus != .authorized {
                            Button("Request Permission") {
                                Task {
                                    await permissions.requestAccessibility()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .frame(width: 450, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await permissions.check()
            }
            permissions.startMonitoring()
            
            // Log window information
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApp.windows.first(where: { $0.isVisible && $0.title == "Inspector" }) {
                    print("Inspector window found:")
                    print("  - Can become key: \(window.canBecomeKey)")
                    print("  - Can become main: \(window.canBecomeMain)")
                    print("  - Is key: \(window.isKeyWindow)")
                    print("  - Is main: \(window.isMainWindow)")
                    print("  - Level: \(window.level)")
                    print("  - ignoresMouseEvents: \(window.ignoresMouseEvents)")
                    print("  - styleMask: \(window.styleMask)")
                }
            }
        }
        .onDisappear {
            permissions.stopMonitoring()
        }
    }
}