import SwiftUI
import UniformTypeIdentifiers

struct LogViewerWindow: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var selectedCategory: ActionCategory?
    @State private var searchText = ""
    @State private var autoScroll = true

    var filteredLogs: [LogEntry] {
        self.actionLogger.entries.filter { entry in
            let matchesCategory = self.selectedCategory == nil || entry.category == self.selectedCategory
            let matchesSearch = self.searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(self.searchText) ||
                (entry.details?.localizedCaseInsensitiveContains(self.searchText) ?? false)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Action Logs")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(self.filteredLogs.count) of \(self.actionLogger.entries.count) entries")
                    .foregroundColor(.secondary)

                Toggle("Auto-scroll", isOn: self.$autoScroll)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            // Filters
            HStack(spacing: 20) {
                // Category filter
                HStack {
                    Text("Category:")
                        .foregroundColor(.secondary)

                    Picker("Category", selection: self.$selectedCategory) {
                        Text("All").tag(nil as ActionCategory?)
                        ForEach(ActionCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category as ActionCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search logs...", text: self.$searchText)
                        .textFieldStyle(.plain)
                    if !self.searchText.isEmpty {
                        Button(action: { self.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                Spacer()

                // Actions
                Button(action: { self.actionLogger.copyLogsToClipboard() }) {
                    Label("Copy All", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { self.actionLogger.clearLogs() }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Log list
            ScrollViewReader { proxy in
                List(self.filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
                .listStyle(.plain)
                .onChange(of: self.filteredLogs.count) { oldCount, newCount in
                    if self.autoScroll, newCount > oldCount, let lastEntry = filteredLogs.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                // Category summary
                HStack(spacing: 15) {
                    ForEach(ActionCategory.allCases, id: \.self) { category in
                        let count = self.actionLogger.entries.count(where: { $0.category == category })
                        if count > 0 { // swiftlint:disable:this empty_count
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 8, height: 8)
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                Button("Export...") {
                    self.exportLogs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
    }

    private func exportLogs() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "peekaboo-logs-\(Date().timeIntervalSince1970).txt"

        savePanel.begin { result in
            Task { @MainActor in
                if result == .OK, let url = savePanel.url {
                    let logContent = self.actionLogger.exportLogs()
                    do {
                        try logContent.write(to: url, atomically: true, encoding: .utf8)
                        self.actionLogger.log(.control, "Logs exported to file", details: url.lastPathComponent)
                    } catch {
                        print("Failed to save logs: \(error)")
                    }
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Category icon
                Image(systemName: self.entry.category.icon)
                    .foregroundColor(self.entry.category.color)
                    .frame(width: 20)

                // Timestamp
                Text(self.entry.formattedTime)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)

                // Category
                Text(self.entry.category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(self.entry.category.color)
                    .frame(width: 60, alignment: .leading)

                // Message
                Text(self.entry.message)
                    .lineLimit(self.isExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Expand button if there are details
                if self.entry.details != nil {
                    Button(action: { self.isExpanded.toggle() }) {
                        Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)

            // Details (when expanded)
            if self.isExpanded, let details = entry.details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20 + 80 + 60 + 16) // Align with message
                    .padding(.bottom, 4)
            }
        }
    }
}
