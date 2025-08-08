//
//  ShortcutSettingsView.swift
//  Peekaboo
//
//  Created by Claude on 2025-08-04.
//

import SwiftUI
import PeekabooCore
import KeyboardShortcuts

struct ShortcutSettingsView: View {
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keyboard Shortcuts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Customize global keyboard shortcuts for quick access")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            
            Section("Global Shortcuts") {
                VStack(spacing: 16) {
                    ShortcutRecorderView(
                        title: "Toggle Popover",
                        shortcutName: .togglePopover
                    )
                    
                    Divider()
                    
                    ShortcutRecorderView(
                        title: "Show Main Window",
                        shortcutName: .showMainWindow
                    )
                    
                    Divider()
                    
                    ShortcutRecorderView(
                        title: "Show Inspector",
                        shortcutName: .showInspector
                    )
                }
                .padding(.vertical, 8)
            }
            
            Section("Instructions") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("How to record shortcuts:")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Click \"Record\" next to any shortcut", systemImage: "1.circle")
                        Label("Press your desired key combination", systemImage: "2.circle")
                        Label("Click \"Done\" to save or \"Cancel\" to abort", systemImage: "3.circle")
                        Label("Use \"Clear\" to remove a shortcut entirely", systemImage: "4.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tips:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Shortcuts must include at least one modifier key (⌘, ⌥, ⌃, or ⇧)")
                        Text("• Avoid common system shortcuts like ⌘Space or ⌘Tab")
                        Text("• Changes take effect immediately without restart")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    ShortcutSettingsView()
        .frame(width: 650, height: 600)
}