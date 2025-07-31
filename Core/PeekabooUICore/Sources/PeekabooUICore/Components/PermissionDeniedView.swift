//
//  PermissionDeniedView.swift
//  PeekabooUICore
//
//  View shown when accessibility permissions are denied
//

import SwiftUI
import AppKit

public struct PermissionDeniedView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Accessibility Permission Required")
                .font(.headline)
            
            Text("Peekaboo Inspector needs accessibility permissions to detect UI elements.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    )
                }
                .buttonStyle(.borderedProminent)
                
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Checking for permission...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("After granting permission, the app will automatically detect it.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}