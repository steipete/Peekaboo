//
//  ElementDetailsView.swift
//  PeekabooUICore
//
//  Displays detailed information about a UI element
//

import SwiftUI
import AppKit
import PeekabooCore

public struct ElementDetailsView: View {
    let element: OverlayManager.UIElement
    @EnvironmentObject var overlayManager: OverlayManager
    @State private var isExpanded = true
    
    public init(element: OverlayManager.UIElement) {
        self.element = element
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            if isExpanded {
                Divider()
                identificationSection
                
                Divider()
                contentSection
                
                Divider()
                propertiesSection
                
                Divider()
                frameSection
                
                if !element.children.isEmpty {
                    Divider()
                    hierarchySection
                }
                
                if element.isActionable {
                    Divider()
                    actionsSection
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var headerSection: some View {
        HStack {
            Circle()
                .fill(element.color)
                .frame(width: 12, height: 12)
            
            Text(element.elementID)
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(element.color)
            
            Text(element.displayName)
                .font(.headline)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var identificationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Identification")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            InfoRow(label: "Role", value: element.role)
            if let roleDesc = element.roleDescription {
                InfoRow(label: "Role Description", value: roleDesc)
            }
            if let identifier = element.identifier {
                InfoRow(label: "Identifier", value: identifier)
            }
            if let className = element.className {
                InfoRow(label: "Class", value: className)
            }
            InfoRow(label: "App Bundle", value: element.appBundleID)
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Content")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if let title = element.title {
                InfoRow(label: "Title", value: title)
            }
            if let label = element.label {
                InfoRow(label: "Label", value: label)
            }
            if let value = element.value {
                InfoRow(label: "Value", value: value)
            }
            if let help = element.help {
                InfoRow(label: "Help", value: help)
            }
            if let selectedText = element.selectedText {
                InfoRow(label: "Selected Text", value: selectedText)
            }
            if let charCount = element.numberOfCharacters {
                InfoRow(label: "Character Count", value: "\(charCount)")
            }
        }
    }
    
    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Properties")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                PropertyBadge(
                    label: "Enabled",
                    isActive: element.isEnabled,
                    activeColor: .green,
                    inactiveColor: .red
                )
                
                PropertyBadge(
                    label: "Focused",
                    isActive: element.isFocused,
                    activeColor: .blue,
                    inactiveColor: .gray
                )
                
                if element.isActionable {
                    PropertyBadge(
                        label: "Actionable",
                        isActive: true,
                        activeColor: .purple,
                        inactiveColor: .gray
                    )
                }
            }
        }
    }
    
    private var frameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Frame")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Position")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("(\(Int(element.frame.origin.x)), \(Int(element.frame.origin.y)))")
                        .font(.system(.caption, design: .monospaced))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(element.frame.width)) × \(Int(element.frame.height))")
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
    }
    
    private var hierarchySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hierarchy")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(element.children.count) child element\(element.children.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Copy ID") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(element.elementID, forType: .string)
                }
                .buttonStyle(.bordered)
                
                Button("Copy Info") {
                    let info = generateElementInfo()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(info, forType: .string)
                }
                .buttonStyle(.bordered)
                
                if element.isActionable {
                    Button("Simulate Click") {
                        // Would trigger click simulation
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private func generateElementInfo() -> String {
        var info = """
        Element: \(element.elementID)
        Role: \(element.role)
        Display Name: \(element.displayName)
        Frame: \(element.frame)
        Bundle ID: \(element.appBundleID)
        """
        
        if let title = element.title {
            info += "\nTitle: \(title)"
        }
        if let label = element.label {
            info += "\nLabel: \(label)"
        }
        if let value = element.value {
            info += "\nValue: \(value)"
        }
        
        return info
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
            
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PropertyBadge: View {
    let label: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? activeColor : inactiveColor)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isActive ? activeColor.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }
}