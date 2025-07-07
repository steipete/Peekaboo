import AppKit
import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var overlayManager: OverlayManager
    @State private var showPermissionAlert = false
    @State private var permissionStatus: PermissionStatus = .checking
    @State private var permissionCheckTimer: Timer?

    enum PermissionStatus {
        case checking
        case granted
        case denied
    }

    var body: some View {
        VStack(spacing: 0) {
            self.headerView

            Divider()

            if self.permissionStatus == .denied {
                self.permissionDeniedView
            } else if self.permissionStatus == .checking {
                ProgressView("Checking permissions...")
                    .padding()
            } else {
                self.mainContent
            }
        }
        .frame(width: 450, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            self.startPermissionMonitoring()
            self.openOverlayWindow()
        }
        .onDisappear {
            self.stopPermissionMonitoring()
        }
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peekaboo Inspector")
                        .font(.headline)
                    Text(self.overlayManager.applications
                        .isEmpty ? "Hover over UI elements to inspect" :
                        "Monitoring \(self.overlayManager.applications.count) app\(self.overlayManager.applications.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("Overlay", isOn: self.$overlayManager.isOverlayActive)
                    .toggleStyle(.switch)
            }
            .padding()

            Divider()

            self.appSelectorView
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let hoveredElement = overlayManager.hoveredElement {
                    self.elementDetailsView(for: hoveredElement)
                } else {
                    Text("Hover over an element to see details")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                Divider()

                self.allElementsView
            }
            .padding()
        }
    }

    private var appSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Target Applications")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Menu("Detail Level") {
                    Button("Essential (Buttons & Inputs)") {
                        self.overlayManager.setDetailLevel(.essential)
                    }
                    .disabled(self.overlayManager.detailLevel == .essential)

                    Button("Moderate (Include Lists & Tables)") {
                        self.overlayManager.setDetailLevel(.moderate)
                    }
                    .disabled(self.overlayManager.detailLevel == .moderate)

                    Button("All (Show Everything)") {
                        self.overlayManager.setDetailLevel(.all)
                    }
                    .disabled(self.overlayManager.detailLevel == .all)
                }
                .menuStyle(.borderlessButton)
                .padding(.trailing, 8)

                Menu {
                    Button("All Applications") {
                        self.overlayManager.setAppSelectionMode(.all)
                    }
                    .disabled(self.overlayManager.selectedAppMode == .all)

                    Divider()

                    // Add TextEdit-only option at the top
                    Button("TextEdit Only (Debug Mode)") {
                        self.overlayManager.setAppSelectionMode(.single, bundleID: "com.apple.TextEdit")
                    }
                    .disabled(self.overlayManager.selectedAppMode == .single && self.overlayManager
                        .selectedAppBundleID == "com.apple.TextEdit")

                    Divider()

                    ForEach(self.overlayManager.applications) { app in
                        Button(action: {
                            self.overlayManager.setAppSelectionMode(.single, bundleID: app.bundleIdentifier)
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
                        .disabled(self.overlayManager.selectedAppMode == .single && self.overlayManager
                            .selectedAppBundleID == app.bundleIdentifier)
                    }
                } label: {
                    HStack {
                        if self.overlayManager.selectedAppMode == .all {
                            Image(systemName: "apps.iphone")
                            Text("All Applications")
                        } else if let selectedID = overlayManager.selectedAppBundleID,
                                  let app = overlayManager.applications
                                      .first(where: { $0.bundleIdentifier == selectedID })
                        {
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

            if self.overlayManager.selectedAppMode == .single {
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

    private func elementDetailsView(for element: OverlayManager.UIElement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hovered Element")
                    .font(.headline)
                Spacer()
                Text(element.elementID)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(element.color.opacity(0.2))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Role", value: element.role)
                if let roleDesc = element.roleDescription {
                    DetailRow(label: "Role Description", value: roleDesc)
                }
                if let title = element.title {
                    DetailRow(label: "Title", value: title)
                }
                if let label = element.label {
                    DetailRow(label: "Label", value: label)
                }
                if let value = element.value {
                    DetailRow(label: "Value", value: value)
                }
                if let help = element.help {
                    DetailRow(label: "Help", value: help)
                }
                DetailRow(label: "Frame", value: self.frameString(element.frame))
                DetailRow(
                    label: "Position",
                    value: "x: \(Int(element.frame.origin.x)) y: \(Int(element.frame.origin.y))")
                DetailRow(
                    label: "Size",
                    value: "width: \(Int(element.frame.width)) height: \(Int(element.frame.height))")
                DetailRow(label: "Enabled", value: element.isEnabled ? "true" : "false")
                DetailRow(label: "Keyboard Focused", value: element.isFocused ? "true" : "false")
                if let identifier = element.identifier {
                    DetailRow(label: "Identifier", value: identifier)
                }
                if let selectedText = element.selectedText {
                    DetailRow(label: "Selected Text", value: selectedText)
                }
                if let numChars = element.numberOfCharacters {
                    DetailRow(label: "Number Of Characters", value: "\(numChars)")
                }
                DetailRow(label: "Actionable", value: element.isActionable ? "Yes" : "No")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Button("Select Element") {
                    self.overlayManager.selectedElement = element
                }
                .buttonStyle(.borderedProminent)

                Button("Copy Info") {
                    self.copyElementInfo(element)
                }
            }
        }
    }

    private var allElementsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let totalElements = self.overlayManager.applications.flatMap(\.elements).count
            Text("All Elements (\(totalElements))")
                .font(.headline)

            ForEach(self.overlayManager.applications) { app in
                if !app.elements.isEmpty {
                    DisclosureGroup {
                        ForEach(app.elements) { element in
                            HStack {
                                Circle()
                                    .fill(element.color)
                                    .frame(width: 8, height: 8)

                                Text(element.elementID)
                                    .font(.system(.caption, design: .monospaced))

                                Text(element.displayName)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(element.id == self.overlayManager.hoveredElement?.id ?
                                        Color.accentColor.opacity(0.1) : Color.clear))
                            .onTapGesture {
                                self.overlayManager.selectedElement = element
                            }
                        }
                    } label: {
                        HStack {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(app.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("(\(app.elements.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    private var permissionDeniedView: some View {
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
                    NSWorkspace.shared
                        .open(
                            URL(
                                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
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

    private func checkPermissions(prompt: Bool = false) {
        let accessEnabled: Bool
        if prompt {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
            accessEnabled = AXIsProcessTrustedWithOptions(options)
        } else {
            accessEnabled = AXIsProcessTrusted()
        }

        let newStatus: PermissionStatus = accessEnabled ? .granted : .denied

        // Only update if status changed
        if self.permissionStatus != newStatus {
            withAnimation {
                self.permissionStatus = newStatus
            }

            // If granted, refresh elements immediately
            if newStatus == .granted {
                self.overlayManager.refreshAllApplications()
            }
        }
    }

    private func startPermissionMonitoring() {
        // Initial check with prompt
        self.checkPermissions(prompt: true)

        // Start periodic checking without prompt
        self.permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkPermissions(prompt: false)
        }
    }

    private func stopPermissionMonitoring() {
        self.permissionCheckTimer?.invalidate()
        self.permissionCheckTimer = nil
    }

    private func openOverlayWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "overlay" }) {
                window.orderFront(nil)
            }
        }
    }

    private func frameString(_ frame: CGRect) -> String {
        "(\(Int(frame.origin.x)), \(Int(frame.origin.y))) \(Int(frame.width))×\(Int(frame.height))"
    }

    private func copyElementInfo(_ element: OverlayManager.UIElement) {
        var info = "Element ID: \(element.elementID)\n"
        info += "Role: \(element.role)\n"
        if let title = element.title { info += "Title: \(title)\n" }
        if let label = element.label { info += "Label: \(label)\n" }
        if let value = element.value { info += "Value: \(value)\n" }
        info += "Frame: \(self.frameString(element.frame))\n"
        info += "Actionable: \(element.isActionable ? "Yes" : "No")"

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(self.label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(self.value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }
}
