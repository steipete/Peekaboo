import ArgumentParser
@testable import peekaboo
import XCTest

final class ListCommandTests: XCTestCase {
    // MARK: - Command Parsing Tests

    func testListCommandParsing() throws {
        // Test basic command parsing
        let command = try ListCommand.parse(["running_applications"])

        XCTAssertEqual(command.type, .runningApplications)
        XCTAssertFalse(command.jsonOutput)
    }

    func testListCommandWithJSONOutput() throws {
        // Test JSON output flag
        let command = try ListCommand.parse(["server_status", "--json-output"])

        XCTAssertEqual(command.type, .serverStatus)
        XCTAssertTrue(command.jsonOutput)
    }

    func testListCommandAllTypes() throws {
        // Test all list types parse correctly
        let types: [(String, ListType)] = [
            ("running_applications", .runningApplications),
            ("windows", .windows),
            ("server_status", .serverStatus)
        ]

        for (arg, expectedType) in types {
            let command = try ListCommand.parse([arg])
            XCTAssertEqual(command.type, expectedType)
        }
    }

    func testListCommandWithApp() throws {
        // Test windows list with app filter
        let command = try ListCommand.parse([
            "windows",
            "--app", "Finder"
        ])

        XCTAssertEqual(command.type, .windows)
        XCTAssertEqual(command.app, "Finder")
    }

    func testListCommandWithWindowDetail() throws {
        // Test window detail options
        let command = try ListCommand.parse([
            "windows",
            "--window-detail", "full"
        ])

        XCTAssertEqual(command.type, .windows)
        XCTAssertEqual(command.windowDetail, .full)
    }

    // MARK: - ListType Tests

    func testListTypeRawValues() {
        // Test list type string values
        XCTAssertEqual(ListType.runningApplications.rawValue, "running_applications")
        XCTAssertEqual(ListType.windows.rawValue, "windows")
        XCTAssertEqual(ListType.serverStatus.rawValue, "server_status")
    }

    func testWindowDetailOptionRawValues() {
        // Test window detail option values
        XCTAssertEqual(WindowDetailOption.none.rawValue, "none")
        XCTAssertEqual(WindowDetailOption.basic.rawValue, "basic")
        XCTAssertEqual(WindowDetailOption.full.rawValue, "full")
    }

    // MARK: - Data Structure Tests

    func testApplicationListDataEncoding() throws {
        // Test ApplicationListData JSON encoding
        let appData = ApplicationListData(
            applications: [
                ApplicationInfo(
                    name: "Finder",
                    bundleIdentifier: "com.apple.finder",
                    processIdentifier: 123,
                    isActive: true
                ),
                ApplicationInfo(
                    name: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    processIdentifier: 456,
                    isActive: false
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(appData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        let apps = json?["applications"] as? [[String: Any]]
        XCTAssertEqual(apps?.count, 2)

        let firstApp = apps?.first
        XCTAssertEqual(firstApp?["name"] as? String, "Finder")
        XCTAssertEqual(firstApp?["bundle_identifier"] as? String, "com.apple.finder")
        XCTAssertEqual(firstApp?["process_identifier"] as? Int, 123)
        XCTAssertEqual(firstApp?["is_active"] as? Bool, true)
    }

    func testWindowListDataEncoding() throws {
        // Test WindowListData JSON encoding
        let windowData = WindowListData(
            targetApp: TargetApplicationInfo(
                name: "Finder",
                bundleIdentifier: "com.apple.finder",
                processIdentifier: 123
            ),
            windows: [
                WindowData(
                    windowInfo: WindowInfo(
                        windowID: 1001,
                        owningApplication: "Finder",
                        windowTitle: "Documents",
                        windowIndex: 0,
                        bounds: WindowBounds(x: 100, y: 200, width: 800, height: 600),
                        isOnScreen: true,
                        windowLevel: 0
                    ),
                    hasDetails: true
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(windowData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)

        let targetApp = json?["target_app"] as? [String: Any]
        XCTAssertEqual(targetApp?["name"] as? String, "Finder")

        let windows = json?["windows"] as? [[String: Any]]
        XCTAssertEqual(windows?.count, 1)

        let firstWindow = windows?.first
        let windowInfo = firstWindow?["window_info"] as? [String: Any]
        XCTAssertEqual(windowInfo?["window_id"] as? Int, 1001)
        XCTAssertEqual(windowInfo?["owning_application"] as? String, "Finder")
        XCTAssertEqual(windowInfo?["window_title"] as? String, "Documents")
    }

    func testServerStatusEncoding() throws {
        // Test ServerStatus JSON encoding
        let status = ServerStatus(
            hasScreenRecordingPermission: true,
            hasAccessibilityPermission: false
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(status)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["has_screen_recording_permission"] as? Bool, true)
        XCTAssertEqual(json?["has_accessibility_permission"] as? Bool, false)
    }

    // MARK: - Window Specifier Tests

    func testWindowSpecifierFromApp() {
        // Test window specifier creation from app
        let specifier = WindowSpecifier.app("Finder")

        switch specifier {
        case let .app(name):
            XCTAssertEqual(name, "Finder")
        default:
            XCTFail("Expected app specifier")
        }
    }

    func testWindowSpecifierFromWindowId() {
        // Test window specifier creation from window ID
        let specifier = WindowSpecifier.windowId(123)

        switch specifier {
        case let .windowId(id):
            XCTAssertEqual(id, 123)
        default:
            XCTFail("Expected windowId specifier")
        }
    }

    func testWindowSpecifierActiveWindow() {
        // Test active window specifier
        let specifier = WindowSpecifier.activeWindow

        switch specifier {
        case .activeWindow:
            // Success
            break
        default:
            XCTFail("Expected activeWindow specifier")
        }
    }

    // MARK: - Error Handling Tests

    func testListCommandInvalidType() {
        // Test invalid list type
        XCTAssertThrowsError(try ListCommand.parse(["invalid_type"]))
    }

    func testListCommandMissingType() {
        // Test missing list type
        XCTAssertThrowsError(try ListCommand.parse([]))
    }

    // MARK: - Performance Tests

    func testApplicationInfoEncodingPerformance() throws {
        // Test performance of encoding many applications
        let apps = (0..<100).map { index in
            ApplicationInfo(
                name: "App\(index)",
                bundleIdentifier: "com.example.app\(index)",
                processIdentifier: pid_t(1000 + index),
                isActive: index == 0
            )
        }

        let appData = ApplicationListData(applications: apps)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        measure {
            _ = try? encoder.encode(appData)
        }
    }
}
