import CoreGraphics
import Testing
import PeekabooCore
@testable import peekaboo

@Suite("Models Tests", .tags(.models, .unit))
struct ModelsTests {
    // MARK: - Enum Tests

    @Test("CaptureMode enum values and parsing", .tags(.fast))
    func captureMode() {
        // Test CaptureMode enum values
        #expect(CaptureMode.screen.rawValue == "screen")
        #expect(CaptureMode.window.rawValue == "window")
        #expect(CaptureMode.multi.rawValue == "multi")

        // Test CaptureMode from string
        #expect(CaptureMode(rawValue: "screen") == .screen)
        #expect(CaptureMode(rawValue: "window") == .window)
        #expect(CaptureMode(rawValue: "multi") == .multi)
        #expect(CaptureMode(rawValue: "invalid") == nil)
    }

    @Test("ImageFormat enum values and parsing", .tags(.fast))
    func imageFormat() {
        // Test ImageFormat enum values
        #expect(ImageFormat.png.rawValue == "png")
        #expect(ImageFormat.jpg.rawValue == "jpg")

        // Test ImageFormat from string
        #expect(ImageFormat(rawValue: "png") == .png)
        #expect(ImageFormat(rawValue: "jpg") == .jpg)
        #expect(ImageFormat(rawValue: "invalid") == nil)
    }

    @Test("CaptureFocus enum values and parsing", .tags(.fast))
    func captureFocus() {
        // Test CaptureFocus enum values
        #expect(CaptureFocus.background.rawValue == "background")
        #expect(CaptureFocus.auto.rawValue == "auto")
        #expect(CaptureFocus.foreground.rawValue == "foreground")

        // Test CaptureFocus from string
        #expect(CaptureFocus(rawValue: "background") == .background)
        #expect(CaptureFocus(rawValue: "auto") == .auto)
        #expect(CaptureFocus(rawValue: "foreground") == .foreground)
        #expect(CaptureFocus(rawValue: "invalid") == nil)
    }

    @Test("WindowDetailOption enum values and parsing", .tags(.fast))
    func windowDetailOption() {
        // Test WindowDetailOption enum values
        #expect(WindowDetailOption.off_screen.rawValue == "off_screen")
        #expect(WindowDetailOption.bounds.rawValue == "bounds")
        #expect(WindowDetailOption.ids.rawValue == "ids")

        // Test WindowDetailOption from string
        #expect(WindowDetailOption(rawValue: "off_screen") == .off_screen)
        #expect(WindowDetailOption(rawValue: "bounds") == .bounds)
        #expect(WindowDetailOption(rawValue: "ids") == .ids)
        #expect(WindowDetailOption(rawValue: "invalid") == nil)
    }

    // MARK: - Parameterized Enum Tests

    @Test("CaptureMode raw values are valid", .tags(.fast))
    func captureModeRawValuesValid() {
        let validValues = ["screen", "window", "multi"]
        for rawValue in validValues {
            #expect(CaptureMode(rawValue: rawValue) != nil)
        }
    }

    @Test("ImageFormat raw values are valid", .tags(.fast))
    func imageFormatRawValuesValid() {
        let validValues = ["png", "jpg"]
        for rawValue in validValues {
            #expect(ImageFormat(rawValue: rawValue) != nil)
        }
    }

    @Test("CaptureFocus raw values are valid", .tags(.fast))
    func captureFocusRawValuesValid() {
        let validValues = ["background", "auto", "foreground"]
        for rawValue in validValues {
            #expect(CaptureFocus(rawValue: rawValue) != nil)
        }
    }

    // MARK: - Model Structure Tests

    @Test("WindowBounds initialization and properties", .tags(.fast))
    func windowBounds() {
        let bounds = WindowBounds(x: 100, y: 200, width: 1200, height: 800)

        #expect(bounds.x == 100)
        #expect(bounds.y == 200)
        #expect(bounds.width == 1200)
        #expect(bounds.height == 800)
    }

    @Test("SavedFile with all properties", .tags(.fast))
    func savedFile() {
        let savedFile = SavedFile(
            path: "/tmp/test.png",
            item_label: "Screen 1",
            window_title: "Safari - Main Window",
            window_id: 12345,
            window_index: 0,
            mime_type: "image/png")

        #expect(savedFile.path == "/tmp/test.png")
        #expect(savedFile.item_label == "Screen 1")
        #expect(savedFile.window_title == "Safari - Main Window")
        #expect(savedFile.window_id == 12345)
        #expect(savedFile.window_index == 0)
        #expect(savedFile.mime_type == "image/png")
    }

    @Test("SavedFile with nil optional values", .tags(.fast))
    func savedFileWithNilValues() {
        let savedFile = SavedFile(
            path: "/tmp/screen.png",
            item_label: nil,
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png")

        #expect(savedFile.path == "/tmp/screen.png")
        #expect(savedFile.item_label == nil)
        #expect(savedFile.window_title == nil)
        #expect(savedFile.window_id == nil)
        #expect(savedFile.window_index == nil)
        #expect(savedFile.mime_type == "image/png")
    }

    @Test("ApplicationInfo initialization", .tags(.fast))
    func applicationInfo() {
        let appInfo = ApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234,
            is_active: true,
            window_count: 2)

        #expect(appInfo.app_name == "Safari")
        #expect(appInfo.bundle_id == "com.apple.Safari")
        #expect(appInfo.pid == 1234)
        #expect(appInfo.is_active == true)
        #expect(appInfo.window_count == 2)
    }

    @Test("WindowInfo with bounds", .tags(.fast))
    func windowInfo() {
        let bounds = WindowBounds(x: 100, y: 100, width: 1200, height: 800)
        let windowInfo = WindowInfo(
            window_title: "Safari - Main Window",
            window_id: 12345,
            window_index: 0,
            bounds: bounds,
            is_on_screen: true)

        #expect(windowInfo.window_title == "Safari - Main Window")
        #expect(windowInfo.window_id == 12345)
        #expect(windowInfo.window_index == 0)
        #expect(windowInfo.bounds != nil)
        #expect(windowInfo.bounds?.x == 100)
        #expect(windowInfo.bounds?.y == 100)
        #expect(windowInfo.bounds?.width == 1200)
        #expect(windowInfo.bounds?.height == 800)
        #expect(windowInfo.is_on_screen == true)
    }

    @Test("TargetApplicationInfo", .tags(.fast))
    func targetApplicationInfo() {
        let targetApp = TargetApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234)

        #expect(targetApp.app_name == "Safari")
        #expect(targetApp.bundle_id == "com.apple.Safari")
        #expect(targetApp.pid == 1234)
    }

    // MARK: - Collection Data Tests

    @Test("ApplicationListData contains applications", .tags(.fast))
    func applicationListData() {
        let app1 = ApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234,
            is_active: true,
            window_count: 2)

        let app2 = ApplicationInfo(
            app_name: "Terminal",
            bundle_id: "com.apple.Terminal",
            pid: 5678,
            is_active: false,
            window_count: 1)

        let appListData = ApplicationListData(applications: [app1, app2])

        #expect(appListData.applications.count == 2)
        #expect(appListData.applications[0].app_name == "Safari")
        #expect(appListData.applications[1].app_name == "Terminal")
    }

    @Test("WindowListData with target application", .tags(.fast))
    func windowListData() {
        let bounds = WindowBounds(x: 100, y: 100, width: 1200, height: 800)
        let window = WindowInfo(
            window_title: "Safari - Main Window",
            window_id: 12345,
            window_index: 0,
            bounds: bounds,
            is_on_screen: true)

        let targetApp = TargetApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234)

        let windowListData = WindowListData(
            windows: [window],
            target_application_info: targetApp)

        #expect(windowListData.windows.count == 1)
        #expect(windowListData.windows[0].window_title == "Safari - Main Window")
        #expect(windowListData.target_application_info.app_name == "Safari")
        #expect(windowListData.target_application_info.bundle_id == "com.apple.Safari")
        #expect(windowListData.target_application_info.pid == 1234)
    }

    @Test("ImageCaptureData with saved files", .tags(.fast))
    func imageCaptureData() {
        let savedFile = SavedFile(
            path: "/tmp/test.png",
            item_label: "Screen 1",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png")

        let imageData = ImageCaptureData(saved_files: [savedFile])

        #expect(imageData.saved_files.count == 1)
        #expect(imageData.saved_files[0].path == "/tmp/test.png")
        #expect(imageData.saved_files[0].item_label == "Screen 1")
        #expect(imageData.saved_files[0].mime_type == "image/png")
    }

    // MARK: - Error Tests

    @Test("CaptureError descriptions are user-friendly", .tags(.fast))
    func captureErrorDescriptions() {
        #expect(CaptureError.noDisplaysAvailable.errorDescription == "No displays available for capture.")
        #expect(CaptureError.screenRecordingPermissionDenied.errorDescription!
            .contains("Screen recording permission is required"))
        #expect(CaptureError.invalidDisplayID.errorDescription == "Invalid display ID provided.")
        #expect(CaptureError.captureCreationFailed(nil).errorDescription == "Failed to create the screen capture.")
        #expect(CaptureError.windowNotFound.errorDescription == "The specified window could not be found.")
        #expect(CaptureError.windowCaptureFailed(nil).errorDescription == "Failed to capture the specified window.")
        let fileError = CaptureError.fileWriteError("/tmp/test.png", nil)
        #expect(fileError.errorDescription?
            .starts(with: "Failed to write capture file to path: /tmp/test.png.") == true)
        #expect(CaptureError.appNotFound("Safari")
            .errorDescription == "Application with identifier 'Safari' not found or is not running.")
        #expect(CaptureError.invalidWindowIndex(5, availableCount: 3).errorDescription == "Invalid window index: 5. Available windows: 0-2")
    }

    @Test("CaptureError exit codes", .tags(.fast))
    func captureErrorExitCodes() {
        let testCases: [(CaptureError, Int32)] = [
            (.noDisplaysAvailable, 10),
            (.screenRecordingPermissionDenied, 11),
            (.accessibilityPermissionDenied, 12),
            (.invalidDisplayID, 13),
            (.captureCreationFailed(nil), 14),
            (.windowNotFound, 15),
            (.windowCaptureFailed(nil), 16),
            (.fileWriteError("test", nil), 17),
            (.appNotFound("test"), 18),
            (.invalidWindowIndex(0, availableCount: 0), 19),
            (.invalidArgument("test"), 20),
            (.unknownError("test"), 1),
        ]

        for (error, expectedCode) in testCases {
            #expect(error.exitCode == expectedCode)
        }
    }

    // MARK: - WindowData Tests

    @Test("WindowData initialization from CGRect", .tags(.fast))
    func windowData() {
        let bounds = CGRect(x: 100, y: 200, width: 1200, height: 800)
        let windowData = WindowData(
            windowId: 12345,
            title: "Safari - Main Window",
            bounds: bounds,
            isOnScreen: true,
            windowIndex: 0)

        #expect(windowData.windowId == 12345)
        #expect(windowData.title == "Safari - Main Window")
        #expect(windowData.bounds.origin.x == 100)
        #expect(windowData.bounds.origin.y == 200)
        #expect(windowData.bounds.size.width == 1200)
        #expect(windowData.bounds.size.height == 800)
        #expect(windowData.isOnScreen == true)
        #expect(windowData.windowIndex == 0)
    }

    @Test("WindowSpecifier variants", .tags(.fast))
    func windowSpecifier() {
        let titleSpecifier = WindowSpecifier.title("Main Window")
        let indexSpecifier = WindowSpecifier.index(0)

        switch titleSpecifier {
        case let .title(title):
            #expect(title == "Main Window")
        case .index:
            Issue.record("Expected title specifier")
        }

        switch indexSpecifier {
        case .title:
            Issue.record("Expected index specifier")
        case let .index(index):
            #expect(index == 0)
        }
    }
}

// MARK: - Extended Model Tests

@Suite("Model Edge Cases", .tags(.models, .unit))
struct ModelEdgeCaseTests {
    @Test(
        "WindowBounds with edge values",
        arguments: [
            (x: 0, y: 0, width: 0, height: 0),
            (x: -100, y: -100, width: 100, height: 100),
            (x: Int.max, y: Int.max, width: 1, height: 1),
        ])
    func windowBoundsEdgeCases(
        x: Int, // swiftlint:disable:this identifier_name
        y: Int, // swiftlint:disable:this identifier_name
        width: Int,
        height: Int)
    {
        let bounds = WindowBounds(x: x, y: y, width: width, height: height)
        #expect(bounds.x == x)
        #expect(bounds.y == y)
        #expect(bounds.width == width)
        #expect(bounds.height == height)
    }

    @Test("ApplicationInfo with extreme values", .tags(.fast))
    func applicationInfoExtremeValues() {
        let appInfo = ApplicationInfo(
            app_name: String(repeating: "A", count: 1000),
            bundle_id: String(repeating: "com.test.", count: 100),
            pid: Int32.max,
            is_active: true,
            window_count: Int.max)

        #expect(appInfo.app_name.count == 1000)
        #expect(appInfo.bundle_id.contains("com.test."))
        #expect(appInfo.pid == Int32.max)
        #expect(appInfo.window_count == Int.max)
    }

    @Test(
        "SavedFile path validation",
        arguments: [
            "/tmp/test.png",
            "/Users/test/Desktop/screenshot.jpg",
            "~/Documents/capture.png",
            "./relative/path/image.png",
            "/path with spaces/image.png",
            "/path/with/特殊文字.png"
        ])
    func savedFilePathValidation(path: String) {
        let savedFile = SavedFile(
            path: path,
            item_label: nil,
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png")

        #expect(savedFile.path == path)
        #expect(!savedFile.path.isEmpty)
    }

    @Test(
        "MIME type validation",
        arguments: ["image/png", "image/jpeg", "image/jpg"])
    func mimeTypeValidation(mimeType: String) {
        let savedFile = SavedFile(
            path: "/tmp/test",
            item_label: nil,
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: mimeType)

        #expect(savedFile.mime_type == mimeType)
        #expect(savedFile.mime_type.starts(with: "image/"))
    }
}
