import AppKit
import CoreGraphics
import PeekabooFoundation
import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Suite("Focus Utilities Tests")
struct FocusUtilitiesTests {
    // MARK: - FocusOptions Tests

    @Test("FocusOptions default values")
    func focusOptionsDefaults() {
        let options = FocusOptions()

        #expect(options.autoFocus == true)
        #expect(options.focusTimeout == nil)
        #expect(options.focusRetryCount == nil)
        #expect(options.spaceSwitch == false)
        #expect(options.bringToCurrentSpace == false)
    }

    @Test("FocusOptions protocol conformance")
    func focusOptionsProtocolConformance() {
        let options = FocusOptions(
            autoFocus: false,
            focusTimeout: 10.0,
            focusRetryCount: 5,
            spaceSwitch: true,
            bringToCurrentSpace: true)

        let protocolOptions: any FocusOptionsProtocol = options
        #expect(protocolOptions.autoFocus == false)
        #expect(protocolOptions.focusTimeout == 10.0)
        #expect(protocolOptions.focusRetryCount == 5)
        #expect(protocolOptions.spaceSwitch == true)
        #expect(protocolOptions.bringToCurrentSpace == true)
    }

    @Test("DefaultFocusOptions values")
    func defaultFocusOptionsValues() {
        let options = DefaultFocusOptions()

        #expect(options.autoFocus == true)
        #expect(options.focusTimeout == 5.0)
        #expect(options.focusRetryCount == 3)
        #expect(options.spaceSwitch == true)
        #expect(options.bringToCurrentSpace == false)
    }

    // MARK: - FocusManagementService Tests

    @Test("FocusManagementService initialization")
    @MainActor
    func focusServiceInit() {
        _ = FocusManagementService()
        // Should initialize without crashing
        // Service is non-optional, so it will always be created
    }

    @Test("FocusOptions struct initialization")
    func focusServiceOptionsInit() {
        let options = FocusManagementService.FocusOptions()

        #expect(options.timeout == 5.0)
        #expect(options.retryCount == 3)
        #expect(options.switchSpace == true)
        #expect(options.bringToCurrentSpace == false)

        let customOptions = FocusManagementService.FocusOptions(
            timeout: 10.0,
            retryCount: 5,
            switchSpace: false,
            bringToCurrentSpace: true)

        #expect(customOptions.timeout == 10.0)
        #expect(customOptions.retryCount == 5)
        #expect(customOptions.switchSpace == false)
        #expect(customOptions.bringToCurrentSpace == true)
    }

    @Test("findBestWindow with non-existent app")
    @MainActor
    func findBestWindowNonExistent() async throws {
        let service = FocusManagementService()

        do {
            _ = try await service.findBestWindow(
                applicationName: "NonExistentApp12345",
                windowTitle: nil)
            Issue.record("Expected to throw for non-existent app")
        } catch {
            // Accept either our typed FocusError or the broader PeekabooError.appNotFound
            let isFocusError = error is FocusError
            let isPeekabooAppError: Bool = if case let .some(.appNotFound(appName)) = (error as? PeekabooError) {
                appName == "NonExistentApp12345"
            } else {
                false
            }
            #expect(isFocusError || isPeekabooAppError)
        }
    }

    @Test("findBestWindow with Finder")
    @MainActor
    func findBestWindowFinder() async throws {
        let service = FocusManagementService()

        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").isEmpty else {
            // Headless CI often runs without Finder; nothing to assert in that case.
            return
        }

        do {
            let windowID = try await service.findBestWindow(
                applicationName: "Finder",
                windowTitle: nil)

            if let id = windowID {
                #expect(id > 0)
            }
            // It's OK if Finder has no windows
        } catch let focusError as FocusError {
            switch focusError {
            case .applicationNotRunning, .noWindowsFound:
                // Acceptable in CI
                return
            default:
                Issue.record("Unexpected error: \(focusError)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("WindowIdentityInfo renderable heuristic")
    func windowRenderableHeuristic() {
        let renderable = WindowIdentityInfo(
            windowID: 42,
            title: "Document",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            ownerPID: 1,
            applicationName: "TestApp",
            bundleIdentifier: "com.example.test",
            windowLayer: 0,
            alpha: 1.0,
            axIdentifier: nil)

        #expect(renderable.isRenderable)

        let tinyBounds = WindowIdentityInfo(
            windowID: 43,
            title: "Helper",
            bounds: CGRect(x: 0, y: 0, width: 5, height: 5),
            ownerPID: 1,
            applicationName: "TestApp",
            bundleIdentifier: "com.example.test",
            windowLayer: 0,
            alpha: 1.0,
            axIdentifier: nil)

        #expect(tinyBounds.isRenderable == false)

        let overlayWindow = WindowIdentityInfo(
            windowID: 44,
            title: "Overlay",
            bounds: CGRect(x: 0, y: 0, width: 400, height: 200),
            ownerPID: 1,
            applicationName: "TestApp",
            bundleIdentifier: "com.example.test",
            windowLayer: 5,
            alpha: 0.5,
            axIdentifier: nil)

        #expect(overlayWindow.isRenderable == false)
    }

    // MARK: - FocusError Tests

    @Test("FocusError descriptions")
    func focusErrorDescriptions() {
        let errors: [FocusError] = [
            .applicationNotRunning("TestApp"),
            .noWindowsFound("TestApp"),
            .windowNotFound(12345),
            .axElementNotFound(12345),
            .focusVerificationFailed(12345),
            .focusVerificationTimeout(12345),
            .timeoutWaitingForCondition,
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!description!.isEmpty)
        }
    }
}

// MARK: - Mock Tests for Session Integration

@Suite("Focus Session Integration Tests")
struct FocusSessionIntegrationTests {
    @Test("Session stores window ID")
    func sessionWindowID() {
        var session = UIAutomationSession(
            version: UIAutomationSession.currentVersion,
            applicationName: "TestApp",
            windowTitle: "Test Window")

        #expect(session.windowID == nil)

        // Set window ID
        session.windowID = 12345
        #expect(session.windowID == 12345)

        // Set AX identifier
        session.windowAXIdentifier = "test-window-id"
        #expect(session.windowAXIdentifier == "test-window-id")

        // Set focus time
        let now = Date()
        session.lastFocusTime = now
        #expect(session.lastFocusTime == now)
    }

    @Test("Session encoding with window info")
    func sessionEncodingWithWindow() throws {
        let session = UIAutomationSession(
            version: UIAutomationSession.currentVersion,
            applicationName: "TestApp",
            windowTitle: "Test Window",
            windowBounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            windowID: 99999,
            windowAXIdentifier: "window-ax-id",
            lastFocusTime: Date())

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UIAutomationSession.self, from: data)

        #expect(decoded.windowID == 99999)
        #expect(decoded.windowAXIdentifier == "window-ax-id")
        #expect(decoded.lastFocusTime != nil)
    }
}
