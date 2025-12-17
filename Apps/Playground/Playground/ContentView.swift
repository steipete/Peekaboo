import Combine
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "boo.peekaboo.playground", category: "Click")

@MainActor
final class PlaygroundTabRouter: ObservableObject {
    @Published var selectedTab: String = "text"
}

struct ContentView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @EnvironmentObject var tabRouter: PlaygroundTabRouter
    @State private var selectedTab: String = "text"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            #if DEBUG
            HStack {
                Text("Debug tab: router=\(self.tabRouter.selectedTab) selection=\(self.selectedTab)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("debug-selected-tab")
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            #endif

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
            .onAppear {
                self.selectedTab = self.tabRouter.selectedTab
            }
            .onChange(of: self.selectedTab) { _, newValue in
                guard self.tabRouter.selectedTab != newValue else { return }
                self.tabRouter.selectedTab = newValue
                self.actionLogger.log(.menu, "Tab changed (selection): \(newValue)")
            }
            .onChange(of: self.tabRouter.selectedTab) { _, newValue in
                guard self.selectedTab != newValue else { return }
                self.selectedTab = newValue
                self.actionLogger.log(.menu, "Tab changed (router): \(newValue)")
            }

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
    @EnvironmentObject var tabRouter: PlaygroundTabRouter

    var body: some View {
        HStack {
            Label("Last Action:", systemImage: "clock.arrow.circlepath")
                .foregroundColor(.secondary)

            Text(self.actionLogger.lastAction)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Tab: \(self.tabRouter.selectedTab)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

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
