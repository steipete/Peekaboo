import ArgumentParser
@testable import peekaboo
import XCTest

final class ListCommandTests: XCTestCase {
    // MARK: - Command Parsing Tests

    func testListCommandSubcommands() throws {
        // Test that ListCommand has the expected subcommands
        XCTAssertEqual(ListCommand.configuration.subcommands.count, 3)
        XCTAssertTrue(ListCommand.configuration.subcommands.contains { $0 == AppsSubcommand.self })
        XCTAssertTrue(ListCommand.configuration.subcommands.contains { $0 == WindowsSubcommand.self })
        XCTAssertTrue(ListCommand.configuration.subcommands.contains { $0 == ServerStatusSubcommand.self })
    }

    func testAppsSubcommandParsing() throws {
        // Test parsing apps subcommand
        let command = try AppsSubcommand.parse([])
        XCTAssertFalse(command.jsonOutput)
    }

    func testAppsSubcommandWithJSONOutput() throws {
        // Test apps subcommand with JSON flag
        let command = try AppsSubcommand.parse(["--json-output"])
        XCTAssertTrue(command.jsonOutput)
    }

    func testWindowsSubcommandParsing() throws {
        // Test parsing windows subcommand with required app
        let command = try WindowsSubcommand.parse(["--app", "Finder"])

        XCTAssertEqual(command.app, "Finder")
        XCTAssertFalse(command.jsonOutput)
        XCTAssertNil(command.includeDetails)
    }

    func testWindowsSubcommandWithDetails() throws {
        // Test windows subcommand with detail options
        let command = try WindowsSubcommand.parse([
            "--app", "Finder",
            "--include-details", "bounds,ids"
        ])

        XCTAssertEqual(command.app, "Finder")
        XCTAssertEqual(command.includeDetails, "bounds,ids")
    }

    // MARK: - Data Structure Tests

    func testApplicationInfoEncoding() throws {
        // Test ApplicationInfo JSON encoding
        let appInfo = ApplicationInfo(
            app_name: "Finder",
            bundle_id: "com.apple.finder",
            pid: 123,
            is_active: true,
            window_count: 5
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(appInfo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["app_name"] as? String, "Finder")
        XCTAssertEqual(json?["bundle_id"] as? String, "com.apple.finder")
        XCTAssertEqual(json?["pid"] as? Int32, 123)
        XCTAssertEqual(json?["is_active"] as? Bool, true)
        XCTAssertEqual(json?["window_count"] as? Int, 5)
    }

    func testApplicationListDataEncoding() throws {
        // Test ApplicationListData JSON encoding
        let appData = ApplicationListData(
            applications: [
                ApplicationInfo(
                    app_name: "Finder",
                    bundle_id: "com.apple.finder",
                    pid: 123,
                    is_active: true,
                    window_count: 3
                ),
                ApplicationInfo(
                    app_name: "Safari",
                    bundle_id: "com.apple.Safari",
                    pid: 456,
                    is_active: false,
                    window_count: 2
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
    }

    func testWindowInfoEncoding() throws {
        // Test WindowInfo JSON encoding
        let windowInfo = WindowInfo(
            window_title: "Documents",
            window_id: 1001,
            window_index: 0,
            bounds: WindowBounds(xCoordinate: 100, yCoordinate: 200, width: 800, height: 600),
            is_on_screen: true
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(windowInfo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["window_title"] as? String, "Documents")
        XCTAssertEqual(json?["window_id"] as? UInt32, 1001)
        XCTAssertEqual(json?["is_on_screen"] as? Bool, true)

        let bounds = json?["bounds"] as? [String: Any]
        XCTAssertEqual(bounds?["x_coordinate"] as? Int, 100)
        XCTAssertEqual(bounds?["y_coordinate"] as? Int, 200)
        XCTAssertEqual(bounds?["width"] as? Int, 800)
        XCTAssertEqual(bounds?["height"] as? Int, 600)
    }

    func testWindowListDataEncoding() throws {
        // Test WindowListData JSON encoding
        let windowData = WindowListData(
            windows: [
                WindowInfo(
                    window_title: "Documents",
                    window_id: 1001,
                    window_index: 0,
                    bounds: WindowBounds(xCoordinate: 100, yCoordinate: 200, width: 800, height: 600),
                    is_on_screen: true
                )
            ],
            target_application_info: TargetApplicationInfo(
                app_name: "Finder",
                bundle_id: "com.apple.finder",
                pid: 123
            )
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(windowData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)

        let windows = json?["windows"] as? [[String: Any]]
        XCTAssertEqual(windows?.count, 1)

        let targetApp = json?["target_application_info"] as? [String: Any]
        XCTAssertEqual(targetApp?["app_name"] as? String, "Finder")
        XCTAssertEqual(targetApp?["bundle_id"] as? String, "com.apple.finder")
    }

    // MARK: - Window Detail Option Tests

    func testWindowDetailOptionRawValues() {
        // Test window detail option values
        XCTAssertEqual(WindowDetailOption.off_screen.rawValue, "off_screen")
        XCTAssertEqual(WindowDetailOption.bounds.rawValue, "bounds")
        XCTAssertEqual(WindowDetailOption.ids.rawValue, "ids")
    }

    // MARK: - Window Specifier Tests

    func testWindowSpecifierTitle() {
        // Test window specifier with title
        let specifier = WindowSpecifier.title("Documents")

        switch specifier {
        case let .title(title):
            XCTAssertEqual(title, "Documents")
        default:
            XCTFail("Expected title specifier")
        }
    }

    func testWindowSpecifierIndex() {
        // Test window specifier with index
        let specifier = WindowSpecifier.index(0)

        switch specifier {
        case let .index(index):
            XCTAssertEqual(index, 0)
        default:
            XCTFail("Expected index specifier")
        }
    }

    // MARK: - Error Handling Tests

    func testWindowsSubcommandMissingApp() {
        // Test that windows subcommand requires app
        XCTAssertThrowsError(try WindowsSubcommand.parse([]))
    }

    // MARK: - Performance Tests

    func testApplicationListEncodingPerformance() throws {
        // Test performance of encoding many applications
        let apps = (0..<100).map { index in
            ApplicationInfo(
                app_name: "App\(index)",
                bundle_id: "com.example.app\(index)",
                pid: Int32(1000 + index),
                is_active: index == 0,
                window_count: index % 5
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
