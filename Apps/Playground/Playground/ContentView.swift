import OSLog
import SwiftUI

private let logger = Logger(subsystem: "boo.peekaboo.playground", category: "Click")

struct ContentView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var selectedTab = "click"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main content area with tabs
            TabView(selection: self.$selectedTab) {
                ClickTestingView()
                    .tabItem { Label("Click Testing", systemImage: "cursorarrow.click") }
                    .tag("click")

                TextInputView()
                    .tabItem { Label("Text Input", systemImage: "textformat") }
                    .tag("text")

                ControlsView()
                    .tabItem { Label("Controls", systemImage: "slider.horizontal.3") }
                    .tag("controls")

                ScrollTestingView()
                    .tabItem { Label("Scroll & Gestures", systemImage: "scroll") }
                    .tag("scroll")

                WindowTestingView()
                    .tabItem { Label("Window", systemImage: "macwindow") }
                    .tag("window")

                DragDropView()
                    .tabItem { Label("Drag & Drop", systemImage: "hand.draw") }
                    .tag("drag")

                KeyboardView()
                    .tabItem { Label("Keyboard", systemImage: "keyboard") }
                    .tag("keyboard")
            }
            .padding()

            Divider()

            // Status bar
            StatusBarView()
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

struct HeaderView: View {
    @EnvironmentObject var actionLogger: ActionLogger

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Peekaboo Playground")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Test all Peekaboo automation features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Text("Actions:")
                        .foregroundColor(.secondary)
                    Text("\(self.actionLogger.actionCount)")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        self.actionLogger.showingLogViewer.toggle()
                    }) {
                        Label("View Logs", systemImage: "doc.text.magnifyingglass")
                    }

                    Button(action: {
                        self.actionLogger.copyLogsToClipboard()
                    }) {
                        Label("Copy Logs", systemImage: "doc.on.clipboard")
                    }

                    Button(action: {
                        self.actionLogger.clearLogs()
                    }) {
                        Label("Clear", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

struct StatusBarView: View {
    @EnvironmentObject var actionLogger: ActionLogger

    var body: some View {
        HStack {
            Label("Last Action:", systemImage: "clock.arrow.circlepath")
                .foregroundColor(.secondary)

            Text(self.actionLogger.lastAction)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(Date(), style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ActionLogger.shared)
        .frame(width: 1200, height: 800)
}
