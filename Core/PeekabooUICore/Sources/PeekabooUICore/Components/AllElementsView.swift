//
//  AllElementsView.swift
//  PeekabooUICore
//
//  Shows a list of all detected UI elements
//

import AppKit
import Observation
import SwiftUI

public struct AllElementsView: View {
    @Bindable private var overlayManager: OverlayManager
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
            case .all: "square.grid.2x2"
            case .buttons: "button.programmable"
            case .textInputs: "text.cursor"
            case .links: "link"
            case .controls: "slider.horizontal.3"
            case .containers: "rectangle.split.3x1"
            case .other: "questionmark.square"
            }
        }
    }

    public init(overlayManager: OverlayManager) {
        self._overlayManager = Bindable(overlayManager)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.headerSection

            if self.filteredElements.isEmpty {
                self.emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(self.groupedElements.keys.sorted(), id: \.self) { appID in
                            if let elements = groupedElements[appID], !elements.isEmpty {
                                AppElementSection(
                                    appBundleID: appID,
                                    elements: elements,
                                    overlayManager: self.overlayManager)
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

                Text("\(self.filteredElements.count) element\(self.filteredElements.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search elements...", text: self.$searchText)
                    .textFieldStyle(.plain)

                if !self.searchText.isEmpty {
                    Button(action: { self.searchText = "" }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    })
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
                            isSelected: self.selectedCategory == category)
                        {
                            self.selectedCategory = category
                        }
                    }

                    Divider()
                        .frame(height: 20)

                    FilterChip(
                        title: "Actionable Only",
                        icon: "hand.tap",
                        isSelected: self.showOnlyActionable)
                    {
                        self.showOnlyActionable.toggle()
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
        self.overlayManager.applications.flatMap(\.elements)
    }

    private var filteredElements: [OverlayManager.UIElement] {
        self.allElements.filter { element in
            // Category filter
            let matchesCategory: Bool = switch self.selectedCategory {
            case .all:
                true
            case .buttons:
                ["AXButton", "AXPopUpButton"].contains(element.role)
            case .textInputs:
                ["AXTextField", "AXTextArea"].contains(element.role)
            case .links:
                element.role == "AXLink"
            case .controls:
                ["AXSlider", "AXCheckBox", "AXRadioButton", "AXPopUpButton"].contains(element.role)
            case .containers:
                ["AXGroup", "AXScrollArea", "AXTable", "AXOutline"].contains(element.role)
            case .other:
                ![
                    "AXButton",
                    "AXPopUpButton",
                    "AXTextField",
                    "AXTextArea",
                    "AXLink",
                    "AXSlider",
                    "AXCheckBox",
                    "AXRadioButton",
                    "AXGroup",
                    "AXScrollArea",
                    "AXTable",
                    "AXOutline",
                ].contains(element.role)
            }

            // Actionable filter
            let matchesActionable = !self.showOnlyActionable || element.isActionable

            // Search filter
            let matchesSearch = self.searchText.isEmpty ||
                element.displayName.localizedCaseInsensitiveContains(self.searchText) ||
                element.elementID.localizedCaseInsensitiveContains(self.searchText) ||
                element.role.localizedCaseInsensitiveContains(self.searchText)

            return matchesCategory && matchesActionable && matchesSearch
        }
    }

    private var groupedElements: [String: [OverlayManager.UIElement]] {
        Dictionary(grouping: self.filteredElements) { $0.appBundleID }
    }
}

// MARK: - Supporting Views

struct AppElementSection: View {
    let appBundleID: String
    let elements: [OverlayManager.UIElement]
    @Bindable private var overlayManager: OverlayManager
    @State private var isExpanded = true

    init(
        appBundleID: String,
        elements: [OverlayManager.UIElement],
        overlayManager: OverlayManager)
    {
        self.appBundleID = appBundleID
        self.elements = elements
        self._overlayManager = Bindable(overlayManager)
    }

    var appName: String {
        self.overlayManager.applications
            .first { $0.bundleIdentifier == self.appBundleID }?.name ?? self.appBundleID
    }

    var appIcon: NSImage? {
        self.overlayManager.applications
            .first { $0.bundleIdentifier == self.appBundleID }?.icon
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

                Text(self.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("(\(self.elements.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isExpanded.toggle()
                    }
                }, label: {
                    Image(systemName: self.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                })
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            // Elements list
            if self.isExpanded {
                ForEach(self.elements) { element in
                    ElementRow(element: element, overlayManager: self.overlayManager)
                }
            }
        }
    }
}

struct ElementRow: View {
    let element: OverlayManager.UIElement
    @Bindable private var overlayManager: OverlayManager
    @State private var isHovered = false

    init(element: OverlayManager.UIElement, overlayManager: OverlayManager) {
        self.element = element
        self._overlayManager = Bindable(overlayManager)
    }

    var isSelected: Bool {
        self.overlayManager.selectedElement?.id == self.element.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Element ID badge
            Text(self.element.elementID)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(self.element.color)
                .cornerRadius(4)

            // Element info
            VStack(alignment: .leading, spacing: 2) {
                Text(self.element.displayName)
                    .font(.caption)
                    .lineLimit(1)

                Text(self.element.role)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action indicators
            if self.element.isActionable {
                Image(systemName: "hand.tap")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !self.element.isEnabled {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(self.isSelected ? Color.accentColor.opacity(0.1) :
                    self.isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(self.isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
        .onHover { hovering in
            self.isHovered = hovering
            if hovering {
                self.overlayManager.hoveredElement = self.element
            }
        }
        .onTapGesture {
            self.overlayManager.selectedElement = self.element
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 4) {
                Image(systemName: self.icon)
                    .font(.caption)
                Text(self.title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(self.isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor)))
            .foregroundColor(self.isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
