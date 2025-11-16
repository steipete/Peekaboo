import OSLog
import SwiftUI

private let logger = Logger(subsystem: "boo.peekaboo.playground", category: "Click")

struct ContentView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @EnvironmentObject var tabRouter: PlaygroundTabRouter

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main content area with tabs
            TabView(selection: self.$tabRouter.selectedTab) {
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
    @EnvironmentObject var tabRouter: PlaygroundTabRouter

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
                    }, label: {
                        Label("View Logs", systemImage: "doc.text.magnifyingglass")
                    })

                    Button(action: {
                        self.actionLogger.copyLogsToClipboard()
                    }, label: {
                        Label("Copy Logs", systemImage: "doc.on.clipboard")
                    })

                    Button(action: {
                        self.actionLogger.clearLogs()
                    }, label: {
                        Label("Clear", systemImage: "trash")
                    })
                    .foregroundColor(.red)

                    Button(action: {
                        self.tabRouter.selectedTab = "drag"
                        self.actionLogger.log(.menu, "Quick switched to Drag & Drop tab")
                    }, label: {
                        Label("Go to Drag & Drop", systemImage: "hand.draw")
                    })
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("nav-drag-tab")
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
        .environmentObject(PlaygroundTabRouter())
        .frame(width: 1200, height: 800)
}
