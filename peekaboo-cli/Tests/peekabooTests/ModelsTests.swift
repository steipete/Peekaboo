@testable import peekaboo
import XCTest

final class ModelsTests: XCTestCase {
    func testCaptureMode() {
        // Test CaptureMode enum values
        XCTAssertEqual(CaptureMode.screen.rawValue, "screen")
        XCTAssertEqual(CaptureMode.window.rawValue, "window")
        XCTAssertEqual(CaptureMode.multi.rawValue, "multi")

        // Test CaptureMode from string
        XCTAssertEqual(CaptureMode(rawValue: "screen"), .screen)
        XCTAssertEqual(CaptureMode(rawValue: "window"), .window)
        XCTAssertEqual(CaptureMode(rawValue: "multi"), .multi)
        XCTAssertNil(CaptureMode(rawValue: "invalid"))
    }

    func testImageFormat() {
        // Test ImageFormat enum values
        XCTAssertEqual(ImageFormat.png.rawValue, "png")
        XCTAssertEqual(ImageFormat.jpg.rawValue, "jpg")

        // Test ImageFormat from string
        XCTAssertEqual(ImageFormat(rawValue: "png"), .png)
        XCTAssertEqual(ImageFormat(rawValue: "jpg"), .jpg)
        XCTAssertNil(ImageFormat(rawValue: "invalid"))
    }

    func testCaptureFocus() {
        // Test CaptureFocus enum values
        XCTAssertEqual(CaptureFocus.background.rawValue, "background")
        XCTAssertEqual(CaptureFocus.foreground.rawValue, "foreground")

        // Test CaptureFocus from string
        XCTAssertEqual(CaptureFocus(rawValue: "background"), .background)
        XCTAssertEqual(CaptureFocus(rawValue: "foreground"), .foreground)
        XCTAssertNil(CaptureFocus(rawValue: "invalid"))
    }

    func testWindowDetailOption() {
        // Test WindowDetailOption enum values
        XCTAssertEqual(WindowDetailOption.off_screen.rawValue, "off_screen")
        XCTAssertEqual(WindowDetailOption.bounds.rawValue, "bounds")
        XCTAssertEqual(WindowDetailOption.ids.rawValue, "ids")

        // Test WindowDetailOption from string
        XCTAssertEqual(WindowDetailOption(rawValue: "off_screen"), .off_screen)
        XCTAssertEqual(WindowDetailOption(rawValue: "bounds"), .bounds)
        XCTAssertEqual(WindowDetailOption(rawValue: "ids"), .ids)
        XCTAssertNil(WindowDetailOption(rawValue: "invalid"))
    }

    func testWindowBounds() {
        let bounds = WindowBounds(xCoordinate: 100, yCoordinate: 200, width: 1200, height: 800)

        XCTAssertEqual(bounds.xCoordinate, 100)
        XCTAssertEqual(bounds.yCoordinate, 200)
        XCTAssertEqual(bounds.width, 1200)
        XCTAssertEqual(bounds.height, 800)
    }

    func testSavedFile() {
        let savedFile = SavedFile(
            path: "/tmp/test.png",
            item_label: "Screen 1",
            window_title: "Safari - Main Window",
            window_id: 12345,
            window_index: 0,
            mime_type: "image/png"
        )

        XCTAssertEqual(savedFile.path, "/tmp/test.png")
        XCTAssertEqual(savedFile.item_label, "Screen 1")
        XCTAssertEqual(savedFile.window_title, "Safari - Main Window")
        XCTAssertEqual(savedFile.window_id, 12345)
        XCTAssertEqual(savedFile.window_index, 0)
        XCTAssertEqual(savedFile.mime_type, "image/png")
    }

    func testSavedFileWithNilValues() {
        let savedFile = SavedFile(
            path: "/tmp/screen.png",
            item_label: nil,
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png"
        )

        XCTAssertEqual(savedFile.path, "/tmp/screen.png")
        XCTAssertNil(savedFile.item_label)
        XCTAssertNil(savedFile.window_title)
        XCTAssertNil(savedFile.window_id)
        XCTAssertNil(savedFile.window_index)
        XCTAssertEqual(savedFile.mime_type, "image/png")
    }

    func testApplicationInfo() {
        let appInfo = ApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234,
            is_active: true,
            window_count: 2
        )

        XCTAssertEqual(appInfo.app_name, "Safari")
        XCTAssertEqual(appInfo.bundle_id, "com.apple.Safari")
        XCTAssertEqual(appInfo.pid, 1234)
        XCTAssertTrue(appInfo.is_active)
        XCTAssertEqual(appInfo.window_count, 2)
    }

    func testWindowInfo() {
        let bounds = WindowBounds(xCoordinate: 100, yCoordinate: 100, width: 1200, height: 800)
        let windowInfo = WindowInfo(
            window_title: "Safari - Main Window",
            window_id: 12345,
            window_index: 0,
            bounds: bounds,
            is_on_screen: true
        )

        XCTAssertEqual(windowInfo.window_title, "Safari - Main Window")
        XCTAssertEqual(windowInfo.window_id, 12345)
        XCTAssertEqual(windowInfo.window_index, 0)
        XCTAssertNotNil(windowInfo.bounds)
        XCTAssertEqual(windowInfo.bounds?.xCoordinate, 100)
        XCTAssertEqual(windowInfo.bounds?.yCoordinate, 100)
        XCTAssertEqual(windowInfo.bounds?.width, 1200)
        XCTAssertEqual(windowInfo.bounds?.height, 800)
        XCTAssertTrue(windowInfo.is_on_screen!)
    }

    func testTargetApplicationInfo() {
        let targetApp = TargetApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234
        )

        XCTAssertEqual(targetApp.app_name, "Safari")
        XCTAssertEqual(targetApp.bundle_id, "com.apple.Safari")
        XCTAssertEqual(targetApp.pid, 1234)
    }

    func testApplicationListData() {
        let app1 = ApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234,
            is_active: true,
            window_count: 2
        )

        let app2 = ApplicationInfo(
            app_name: "Terminal",
            bundle_id: "com.apple.Terminal",
            pid: 5678,
            is_active: false,
            window_count: 1
        )

        let appListData = ApplicationListData(applications: [app1, app2])

        XCTAssertEqual(appListData.applications.count, 2)
        XCTAssertEqual(appListData.applications[0].app_name, "Safari")
        XCTAssertEqual(appListData.applications[1].app_name, "Terminal")
    }

    func testWindowListData() {
        let bounds = WindowBounds(xCoordinate: 100, yCoordinate: 100, width: 1200, height: 800)
        let window = WindowInfo(
            window_title: "Safari - Main Window",
            window_id: 12345,
            window_index: 0,
            bounds: bounds,
            is_on_screen: true
        )

        let targetApp = TargetApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 1234
        )

        let windowListData = WindowListData(
            windows: [window],
            target_application_info: targetApp
        )

        XCTAssertEqual(windowListData.windows.count, 1)
        XCTAssertEqual(windowListData.windows[0].window_title, "Safari - Main Window")
        XCTAssertEqual(windowListData.target_application_info.app_name, "Safari")
        XCTAssertEqual(windowListData.target_application_info.bundle_id, "com.apple.Safari")
        XCTAssertEqual(windowListData.target_application_info.pid, 1234)
    }

    func testImageCaptureData() {
        let savedFile = SavedFile(
            path: "/tmp/test.png",
            item_label: "Screen 1",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: "image/png"
        )

        let imageData = ImageCaptureData(saved_files: [savedFile])

        XCTAssertEqual(imageData.saved_files.count, 1)
        XCTAssertEqual(imageData.saved_files[0].path, "/tmp/test.png")
        XCTAssertEqual(imageData.saved_files[0].item_label, "Screen 1")
        XCTAssertEqual(imageData.saved_files[0].mime_type, "image/png")
    }

    func testCaptureErrorDescriptions() {
        XCTAssertEqual(CaptureError.noDisplaysAvailable.errorDescription, "No displays available for capture.")
        XCTAssertTrue(
            CaptureError.screenRecordingPermissionDenied.errorDescription!.contains("Screen recording permission is required")
        )
        XCTAssertEqual(CaptureError.invalidDisplayID.errorDescription, "Invalid display ID provided.")
        XCTAssertEqual(CaptureError.captureCreationFailed.errorDescription, "Failed to create the screen capture.")
        XCTAssertEqual(CaptureError.windowNotFound.errorDescription, "The specified window could not be found.")
        XCTAssertEqual(CaptureError.windowCaptureFailed.errorDescription, "Failed to capture the specified window.")
        XCTAssertEqual(
            CaptureError.fileWriteError("/tmp/test.png").errorDescription,
            "Failed to write capture file to path: /tmp/test.png."
        )
        XCTAssertEqual(CaptureError.appNotFound("Safari").errorDescription, "Application with identifier 'Safari' not found or is not running.")
        XCTAssertEqual(CaptureError.invalidWindowIndex(5).errorDescription, "Invalid window index: 5.")
    }

    func testWindowData() {
        let bounds = CGRect(x: 100, y: 200, width: 1200, height: 800)
        let windowData = WindowData(
            windowId: 12345,
            title: "Safari - Main Window",
            bounds: bounds,
            isOnScreen: true,
            windowIndex: 0
        )

        XCTAssertEqual(windowData.windowId, 12345)
        XCTAssertEqual(windowData.title, "Safari - Main Window")
        XCTAssertEqual(windowData.bounds.origin.x, 100)
        XCTAssertEqual(windowData.bounds.origin.y, 200)
        XCTAssertEqual(windowData.bounds.size.width, 1200)
        XCTAssertEqual(windowData.bounds.size.height, 800)
        XCTAssertTrue(windowData.isOnScreen)
        XCTAssertEqual(windowData.windowIndex, 0)
    }

    func testWindowSpecifier() {
        let titleSpecifier = WindowSpecifier.title("Main Window")
        let indexSpecifier = WindowSpecifier.index(0)

        switch titleSpecifier {
        case let .title(title):
            XCTAssertEqual(title, "Main Window")
        case .index:
            XCTFail("Expected title specifier")
        }

        switch indexSpecifier {
        case .title:
            XCTFail("Expected index specifier")
        case let .index(index):
            XCTAssertEqual(index, 0)
        }
    }
}
