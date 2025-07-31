//
//  AllElementsView.swift
//  PeekabooUICore
//
//  Shows a list of all detected UI elements
//

import SwiftUI
import AppKit

public struct AllElementsView: View {
    @ObservedObject var overlayManager: OverlayManager
    @State private var searchText = ""
    @State private var selectedCategory: ElementFilterCategory = .all
    @State private var showOnlyActionable = false
    
    enum ElementFilterCategory: String, CaseIterable {
        case all = "All"
        case buttons = "Buttons"
        case textInputs = "Text Inputs"
        case links = "Links"
        case controls = "Controls"
        case containers = "Containers"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .buttons: return "button.programmable"
            case .textInputs: return "text.cursor"
            case .links: return "link"
            case .controls: return "slider.horizontal.3"
            case .containers: return "rectangle.split.3x1"
            case .other: return "questionmark.square"
            }
        }
    }
    
    public init(overlayManager: OverlayManager) {
        self.overlayManager = overlayManager
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            if filteredElements.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(groupedElements.keys.sorted(), id: \.self) { appID in
                            if let elements = groupedElements[appID], !elements.isEmpty {
                                AppElementSection(
                                    appBundleID: appID,
                                    elements: elements,
                                    overlayManager: overlayManager
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("All Elements")
                    .font(.headline)
                
                Spacer()
                
                Text("\(filteredElements.count) element\(filteredElements.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search elements...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            // Filter controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ElementFilterCategory.allCases, id: \.self) { category in
                        FilterChip(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    FilterChip(
                        title: "Actionable Only",
                        icon: "hand.tap",
                        isSelected: showOnlyActionable
                    ) {
                        showOnlyActionable.toggle()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No elements found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your filters or hovering over different applications")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var allElements: [OverlayManager.UIElement] {
        overlayManager.applications.flatMap { $0.elements }
    }
    
    private var filteredElements: [OverlayManager.UIElement] {
        allElements.filter { element in
            // Category filter
            let matchesCategory: Bool = {
                switch selectedCategory {
                case .all:
                    return true
                case .buttons:
                    return ["AXButton", "AXPopUpButton"].contains(element.role)
                case .textInputs:
                    return ["AXTextField", "AXTextArea"].contains(element.role)
                case .links:
                    return element.role == "AXLink"
                case .controls:
                    return ["AXSlider", "AXCheckBox", "AXRadioButton", "AXPopUpButton"].contains(element.role)
                case .containers:
                    return ["AXGroup", "AXScrollArea", "AXTable", "AXOutline"].contains(element.role)
                case .other:
                    return !["AXButton", "AXPopUpButton", "AXTextField", "AXTextArea", "AXLink",
                            "AXSlider", "AXCheckBox", "AXRadioButton", "AXGroup", "AXScrollArea",
                            "AXTable", "AXOutline"].contains(element.role)
                }
            }()
            
            // Actionable filter
            let matchesActionable = !showOnlyActionable || element.isActionable
            
            // Search filter
            let matchesSearch = searchText.isEmpty || 
                element.displayName.localizedCaseInsensitiveContains(searchText) ||
                element.elementID.localizedCaseInsensitiveContains(searchText) ||
                element.role.localizedCaseInsensitiveContains(searchText)
            
            return matchesCategory && matchesActionable && matchesSearch
        }
    }
    
    private var groupedElements: [String: [OverlayManager.UIElement]] {
        Dictionary(grouping: filteredElements) { $0.appBundleID }
    }
}

// MARK: - Supporting Views

struct AppElementSection: View {
    let appBundleID: String
    let elements: [OverlayManager.UIElement]
    @ObservedObject var overlayManager: OverlayManager
    @State private var isExpanded = true
    
    var appName: String {
        overlayManager.applications
            .first { $0.bundleIdentifier == appBundleID }?.name ?? appBundleID
    }
    
    var appIcon: NSImage? {
        overlayManager.applications
            .first { $0.bundleIdentifier == appBundleID }?.icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // App header
            HStack {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                
                Text(appName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("(\(elements.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            // Elements list
            if isExpanded {
                ForEach(elements) { element in
                    ElementRow(element: element, overlayManager: overlayManager)
                }
            }
        }
    }
}

struct ElementRow: View {
    let element: OverlayManager.UIElement
    @ObservedObject var overlayManager: OverlayManager
    @State private var isHovered = false
    
    var isSelected: Bool {
        overlayManager.selectedElement?.id == element.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Element ID badge
            Text(element.elementID)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(element.color)
                .cornerRadius(4)
            
            // Element info
            VStack(alignment: .leading, spacing: 2) {
                Text(element.displayName)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(element.role)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action indicators
            if element.isActionable {
                Image(systemName: "hand.tap")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !element.isEnabled {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : 
                      isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                overlayManager.hoveredElement = element
            }
        }
        .onTapGesture {
            overlayManager.selectedElement = element
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}