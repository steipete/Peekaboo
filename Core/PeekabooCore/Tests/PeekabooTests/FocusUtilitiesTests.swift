import AppKit
import CoreGraphics
import PeekabooFoundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

struct FocusUtilitiesTests {
    // MARK: - FocusOptions Tests

    @Test
    func `FocusOptions default values`() {
        let options = FocusOptions()

        #expect(options.autoFocus == true)
        #expect(options.focusTimeout == nil)
        #expect(options.focusRetryCount == nil)
        #expect(options.spaceSwitch == false)
        #expect(options.bringToCurrentSpace == false)
    }

    @Test
    func `FocusOptions protocol conformance`() {
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

    @Test
    func `DefaultFocusOptions values`() {
        let options = DefaultFocusOptions()

        #expect(options.autoFocus == true)
        #expect(options.focusTimeout == 5.0)
        #expect(options.focusRetryCount == 3)
        #expect(options.spaceSwitch == true)
        #expect(options.bringToCurrentSpace == false)
    }

    // MARK: - FocusManagementService Tests

    @Test
    @MainActor
    func `FocusManagementService initialization`() {
        _ = FocusManagementService()
        // Should initialize without crashing
        // Service is non-optional, so it will always be created
    }

    @Test
    func `FocusOptions struct initialization`() {
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

    @Test
    @MainActor
    func `findBestWindow with non-existent app`() async throws {
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

    @Test
    @MainActor
    func `findBestWindow with Finder`() async throws {
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

    @Test
    func `WindowIdentityInfo renderable heuristic`() {
        let renderable = WindowIdentityInfo(
            windowID: 42,
            title: "Document",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            ownerPID: 1,
            applicationName: "TestApp",
            bundleIdentifier: "com.example.test",
            layer: 0,
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
            layer: 0,
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
            layer: 5,
            alpha: 0.5,
            axIdentifier: nil)

        #expect(overlayWindow.isRenderable == false)
    }

    // MARK: - FocusError Tests

    @Test
    func `FocusError descriptions`() throws {
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
            #expect(try !(#require(description?.isEmpty)))
        }
    }
}
