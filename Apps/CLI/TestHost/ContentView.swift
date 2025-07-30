import AppKit
import SwiftUI

struct ContentView: View {
    @State private var screenRecordingPermission = false
    @State private var accessibilityPermission = false
    @State private var logMessages: [String] = []
    @State private var testStatus = "Ready"
    @State private var peekabooCliAvailable = false

    private let testIdentifier = "PeekabooTestHost"

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Peekaboo Test Host")
                .font(.largeTitle)
                .padding(.top)

            // Window identifier for tests
            Text("Window ID: \(self.testIdentifier)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            // Permission Status
            GroupBox("Permissions") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: self
                            .screenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundColor(self.screenRecordingPermission ? .green : .red)
                        Text("Screen Recording")
                        Spacer()
                        Button("Check") {
                            self.checkScreenRecordingPermission()
                        }
                    }

                    HStack {
                        Image(systemName: self.accessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(self.accessibilityPermission ? .green : .red)
                        Text("Accessibility")
                        Spacer()
                        Button("Check") {
                            self.checkAccessibilityPermission()
                        }
                    }

                    HStack {
                        Image(systemName: self.peekabooCliAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(self.peekabooCliAvailable ? .green : .red)
                        Text("Peekaboo CLI")
                        Spacer()
                        Button("Check") {
                            self.checkPeekabooCli()
                        }
                    }
                }
                .padding()
            }

            // Test Status
            GroupBox("Test Status") {
                VStack(alignment: .leading, spacing: 5) {
                    Text(self.testStatus)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Button("Run Local Tests") {
                            self.runLocalTests()
                        }

                        Button("Clear Logs") {
                            self.logMessages.removeAll()
                            self.testStatus = "Ready"
                        }
                    }
                }
                .padding()
            }

            // Log Messages
            GroupBox("Log Messages") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(self.logMessages.enumerated()), id: \.offset) { _, message in
                            Text(message)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 200, maxHeight: 300)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            self.checkPermissions()
            self.checkPeekabooCli()
            self.addLog("Test host started")
        }
    }

    private func checkPermissions() {
        self.checkScreenRecordingPermission()
        self.checkAccessibilityPermission()
    }

    private func checkScreenRecordingPermission() {
        // Check screen recording permission
        if CGPreflightScreenCaptureAccess() {
            self.screenRecordingPermission = CGRequestScreenCaptureAccess()
        } else {
            self.screenRecordingPermission = false
        }
        self.addLog("Screen recording permission: \(self.screenRecordingPermission)")
    }

    private func checkAccessibilityPermission() {
        self.accessibilityPermission = AXIsProcessTrusted()
        self.addLog("Accessibility permission: \(self.accessibilityPermission)")
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        self.logMessages.append("[\(timestamp)] \(message)")

        // Keep only last 100 messages
        if self.logMessages.count > 100 {
            self.logMessages.removeFirst()
        }
    }

    private func checkPeekabooCli() {
        let cliPath = "../.build/debug/peekaboo"
        if FileManager.default.fileExists(atPath: cliPath) {
            self.peekabooCliAvailable = true
            self.addLog("Peekaboo CLI found at: \(cliPath)")
        } else {
            self.peekabooCliAvailable = false
            self.addLog("Peekaboo CLI not found. Run 'swift build' first.")
        }
    }

    private func runLocalTests() {
        self.testStatus = "Running tests..."
        self.addLog("Starting local test suite")

        // This is where the Swift tests can interact with the host app
        // The tests can find this window by its identifier and perform actions

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.testStatus = "Tests can now interact with this window"
            self.addLog("Window is ready for test interactions")
            self.addLog("Run: swift test --enable-test-discovery --filter LocalIntegration")
        }
    }
}

// Test helper view for creating specific test scenarios
struct TestPatternView: View {
    let pattern: TestPattern

    enum TestPattern {
        case solid(Color)
        case gradient
        case text(String)
        case grid
    }

    var body: some View {
        switch self.pattern {
        case let .solid(color):
            Rectangle()
                .fill(color)
        case .gradient:
            LinearGradient(
                colors: [.red, .yellow, .green, .blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case let .text(string):
            Text(string)
                .font(.largeTitle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
        case .grid:
            GeometryReader { geometry in
                Path { path in
                    let gridSize: CGFloat = 20
                    let width = geometry.size.width
                    let height = geometry.size.height

                    // Vertical lines
                    for x in stride(from: 0, through: width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }

                    // Horizontal lines
                    for y in stride(from: 0, through: height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            }
        }
    }
}
