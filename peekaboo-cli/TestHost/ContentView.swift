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
            Text("Window ID: \(testIdentifier)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            // Permission Status
            GroupBox("Permissions") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: screenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(screenRecordingPermission ? .green : .red)
                        Text("Screen Recording")
                        Spacer()
                        Button("Check") {
                            checkScreenRecordingPermission()
                        }
                    }

                    HStack {
                        Image(systemName: accessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(accessibilityPermission ? .green : .red)
                        Text("Accessibility")
                        Spacer()
                        Button("Check") {
                            checkAccessibilityPermission()
                        }
                    }

                    HStack {
                        Image(systemName: peekabooCliAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(peekabooCliAvailable ? .green : .red)
                        Text("Peekaboo CLI")
                        Spacer()
                        Button("Check") {
                            checkPeekabooCli()
                        }
                    }
                }
                .padding()
            }

            // Test Status
            GroupBox("Test Status") {
                VStack(alignment: .leading, spacing: 5) {
                    Text(testStatus)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Button("Run Local Tests") {
                            runLocalTests()
                        }

                        Button("Clear Logs") {
                            logMessages.removeAll()
                            testStatus = "Ready"
                        }
                    }
                }
                .padding()
            }

            // Log Messages
            GroupBox("Log Messages") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logMessages.enumerated()), id: \.offset) { _, message in
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
            checkPermissions()
            checkPeekabooCli()
            addLog("Test host started")
        }
    }

    private func checkPermissions() {
        checkScreenRecordingPermission()
        checkAccessibilityPermission()
    }

    private func checkScreenRecordingPermission() {
        // Check screen recording permission
        if CGPreflightScreenCaptureAccess() {
            screenRecordingPermission = CGRequestScreenCaptureAccess()
        } else {
            screenRecordingPermission = false
        }
        addLog("Screen recording permission: \(screenRecordingPermission)")
    }

    private func checkAccessibilityPermission() {
        accessibilityPermission = AXIsProcessTrusted()
        addLog("Accessibility permission: \(accessibilityPermission)")
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logMessages.append("[\(timestamp)] \(message)")

        // Keep only last 100 messages
        if logMessages.count > 100 {
            logMessages.removeFirst()
        }
    }

    private func checkPeekabooCli() {
        let cliPath = "../.build/debug/peekaboo"
        if FileManager.default.fileExists(atPath: cliPath) {
            peekabooCliAvailable = true
            addLog("Peekaboo CLI found at: \(cliPath)")
        } else {
            peekabooCliAvailable = false
            addLog("Peekaboo CLI not found. Run 'swift build' first.")
        }
    }

    private func runLocalTests() {
        testStatus = "Running embedded tests..."
        addLog("Starting test execution from within app")
        
        // Set environment for tests
        setenv("RUN_LOCAL_TESTS", "true", 1)
        
        // Run the XCTest tests
        DispatchQueue.global(qos: .userInitiated).async {
            let testSuite = XCTestSuite(forTestCaseClass: LocalIntegrationTests.self)
            let testRun = testSuite.run()
            
            DispatchQueue.main.async {
                self.testStatus = "Tests completed: \(testRun.testCaseCount - testRun.failureCount)/\(testRun.testCaseCount) passed"
                self.addLog("Test execution finished")
                self.addLog("Total: \(testRun.testCaseCount) tests")
                self.addLog("Passed: \(testRun.testCaseCount - testRun.failureCount)")
                self.addLog("Failed: \(testRun.failureCount)")
                self.addLog("Duration: \(String(format: "%.2f", testRun.testDuration))s")
            }
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
        switch pattern {
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
