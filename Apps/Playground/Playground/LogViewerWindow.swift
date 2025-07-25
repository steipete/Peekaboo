import SwiftUI
import UniformTypeIdentifiers

struct LogViewerWindow: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var selectedCategory: ActionCategory?
    @State private var searchText = ""
    @State private var autoScroll = true
    
    var filteredLogs: [LogEntry] {
        actionLogger.entries.filter { entry in
            let matchesCategory = selectedCategory == nil || entry.category == selectedCategory
            let matchesSearch = searchText.isEmpty || 
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                (entry.details?.localizedCaseInsensitiveContains(searchText) ?? false)
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
                
                Text("\(filteredLogs.count) of \(actionLogger.entries.count) entries")
                    .foregroundColor(.secondary)
                
                Toggle("Auto-scroll", isOn: $autoScroll)
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
                    
                    Picker("Category", selection: $selectedCategory) {
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
                    TextField("Search logs...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
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
                Button(action: { actionLogger.copyLogsToClipboard() }) {
                    Label("Copy All", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: { actionLogger.clearLogs() }) {
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
                List(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
                .listStyle(.plain)
                .onChange(of: filteredLogs.count) { oldCount, newCount in
                    if autoScroll && newCount > oldCount, let lastEntry = filteredLogs.last {
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
                        let count = actionLogger.entries.filter { $0.category == category }.count
                        if count > 0 {
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
                    exportLogs()
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
                    let logContent = actionLogger.exportLogs()
                    do {
                        try logContent.write(to: url, atomically: true, encoding: .utf8)
                        actionLogger.log(.control, "Logs exported to file", details: url.lastPathComponent)
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
                Image(systemName: entry.category.icon)
                    .foregroundColor(entry.category.color)
                    .frame(width: 20)
                
                // Timestamp
                Text(entry.formattedTime)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                // Category
                Text(entry.category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(entry.category.color)
                    .frame(width: 60, alignment: .leading)
                
                // Message
                Text(entry.message)
                    .lineLimit(isExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Expand button if there are details
                if entry.details != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
            
            // Details (when expanded)
            if isExpanded, let details = entry.details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20 + 80 + 60 + 16) // Align with message
                    .padding(.bottom, 4)
            }
        }
    }
}