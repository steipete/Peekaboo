import CoreGraphics
import Testing
@testable import PeekabooCore

@Suite("Application Models Tests", .tags(.models, .unit))
struct ApplicationModelsTests {
    // MARK: - Enum Tests
    
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

    // MARK: - Model Structure Tests

    @Test("WindowBounds initialization and properties", .tags(.fast))
    func windowBounds() {
        let bounds = WindowBounds(x: 100, y: 200, width: 1200, height: 800)

        #expect(bounds.x == 100)
        #expect(bounds.y == 200)
        #expect(bounds.width == 1200)
        #expect(bounds.height == 800)
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

    @Test("WindowInfo initialization", .tags(.fast))
    func windowInfo() {
        let bounds = WindowBounds(x: 100, y: 200, width: 1200, height: 800)
        let windowInfo = WindowInfo(
            window_title: "Safari - Main Window",
            window_id: 12345,
            window_index: 0,
            bounds: bounds,
            is_on_screen: true
        )

        #expect(windowInfo.window_title == "Safari - Main Window")
        #expect(windowInfo.window_id == 12345)
        #expect(windowInfo.window_index == 0)
        #expect(windowInfo.bounds != nil)
        #expect(windowInfo.bounds?.x == 100)
        #expect(windowInfo.bounds?.y == 200)
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
}