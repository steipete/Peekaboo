// swiftlint:disable file_length
import ArgumentParser
import Foundation
@testable import peekaboo
import Testing

@Suite("ListCommand Tests", .tags(.unit))
// swiftlint:disable:next type_body_length
struct ListCommandTests {
    // MARK: - Command Parsing Tests

    @Test("ListCommand has correct subcommands", .tags(.fast))
    func listCommandSubcommands() throws {
        // Test that ListCommand has the expected subcommands
        #expect(ListCommand.configuration.subcommands.count == 3)
        #expect(ListCommand.configuration.subcommands.contains { $0 == AppsSubcommand.self })
        #expect(ListCommand.configuration.subcommands.contains { $0 == WindowsSubcommand.self })
        #expect(ListCommand.configuration.subcommands.contains { $0 == ServerStatusSubcommand.self })
    }

    @Test("AppsSubcommand parsing with defaults", .tags(.fast))
    func appsSubcommandParsing() throws {
        // Test parsing apps subcommand
        let command = try AppsSubcommand.parse([])
        #expect(command.jsonOutput == false)
    }

    @Test("AppsSubcommand with JSON output flag", .tags(.fast))
    func appsSubcommandWithJSONOutput() throws {
        // Test apps subcommand with JSON flag
        let command = try AppsSubcommand.parse(["--json-output"])
        #expect(command.jsonOutput == true)
    }

    @Test("WindowsSubcommand parsing with required app", .tags(.fast))
    func windowsSubcommandParsing() throws {
        // Test parsing windows subcommand with required app
        let command = try WindowsSubcommand.parse(["--app", "Finder"])

        #expect(command.app == "Finder")
        #expect(command.jsonOutput == false)
        #expect(command.includeDetails == nil)
    }

    @Test("WindowsSubcommand with detail options", .tags(.fast))
    func windowsSubcommandWithDetails() throws {
        // Test windows subcommand with detail options
        let command = try WindowsSubcommand.parse([
            "--app", "Finder",
            "--include-details", "bounds,ids"
        ])

        #expect(command.app == "Finder")
        #expect(command.includeDetails == "bounds,ids")
    }

    @Test("WindowsSubcommand requires app parameter", .tags(.fast))
    func windowsSubcommandMissingApp() {
        // Test that windows subcommand requires app
        #expect(throws: (any Error).self) {
            try WindowsSubcommand.parse([])
        }
    }

    // MARK: - Parameterized Command Tests

    @Test(
        "WindowsSubcommand detail parsing",
        arguments: [
            "off_screen",
            "bounds",
            "ids",
            "off_screen,bounds",
            "bounds,ids",
            "off_screen,bounds,ids"
        ]
    )
    func windowsDetailParsing(details: String) throws {
        let command = try WindowsSubcommand.parse([
            "--app", "Safari",
            "--include-details", details
        ])

        #expect(command.includeDetails == details)
    }

    // MARK: - Data Structure Tests

    @Test("ApplicationInfo JSON encoding", .tags(.fast))
    func applicationInfoEncoding() throws {
        // Test ApplicationInfo JSON encoding
        let appInfo = ApplicationInfo(
            app_name: "Finder",
            bundle_id: "com.apple.finder",
            pid: 123,
            is_active: true,
            window_count: 5
        )

        let encoder = JSONEncoder()
        // Properties are already in snake_case, no conversion needed

        let data = try encoder.encode(appInfo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        #expect(json?["app_name"] as? String == "Finder")
        #expect(json?["bundle_id"] as? String == "com.apple.finder")
        #expect(json?["pid"] as? Int32 == 123)
        #expect(json?["is_active"] as? Bool == true)
        #expect(json?["window_count"] as? Int == 5)
    }

    @Test("ApplicationListData JSON encoding", .tags(.fast))
    func applicationListDataEncoding() throws {
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
        // Properties are already in snake_case, no conversion needed

        let data = try encoder.encode(appData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        let apps = json?["applications"] as? [[String: Any]]
        #expect(apps?.count == 2)
    }

    @Test("WindowInfo JSON encoding", .tags(.fast))
    func windowInfoEncoding() throws {
        // Test WindowInfo JSON encoding
        let windowInfo = WindowInfo(
            window_title: "Documents",
            window_id: 1001,
            window_index: 0,
            bounds: WindowBounds(x: 100, y: 200, width: 800, height: 600),
            is_on_screen: true
        )

        let encoder = JSONEncoder()
        // Properties are already in snake_case, no conversion needed

        let data = try encoder.encode(windowInfo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)
        #expect(json?["window_title"] as? String == "Documents")
        #expect(json?["window_id"] as? UInt32 == 1001)
        #expect(json?["is_on_screen"] as? Bool == true)

        let bounds = json?["bounds"] as? [String: Any]
        #expect(bounds?["x"] as? Int == 100)
        #expect(bounds?["y"] as? Int == 200)
        #expect(bounds?["width"] as? Int == 800)
        #expect(bounds?["height"] as? Int == 600)
    }

    @Test("WindowListData JSON encoding", .tags(.fast))
    func windowListDataEncoding() throws {
        // Test WindowListData JSON encoding
        let windowData = WindowListData(
            windows: [
                WindowInfo(
                    window_title: "Documents",
                    window_id: 1001,
                    window_index: 0,
                    bounds: WindowBounds(x: 100, y: 200, width: 800, height: 600),
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
        // Properties are already in snake_case, no conversion needed

        let data = try encoder.encode(windowData)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json != nil)

        let windows = json?["windows"] as? [[String: Any]]
        #expect(windows?.count == 1)

        let targetApp = json?["target_application_info"] as? [String: Any]
        #expect(targetApp?["app_name"] as? String == "Finder")
        #expect(targetApp?["bundle_id"] as? String == "com.apple.finder")
    }

    // MARK: - Window Detail Option Tests

    @Test("WindowDetailOption raw values", .tags(.fast))
    func windowDetailOptionRawValues() {
        // Test window detail option values
        #expect(WindowDetailOption.off_screen.rawValue == "off_screen")
        #expect(WindowDetailOption.bounds.rawValue == "bounds")
        #expect(WindowDetailOption.ids.rawValue == "ids")
    }

    // MARK: - Window Specifier Tests

    @Test("WindowSpecifier with title", .tags(.fast))
    func windowSpecifierTitle() {
        // Test window specifier with title
        let specifier = WindowSpecifier.title("Documents")

        switch specifier {
        case let .title(title):
            #expect(title == "Documents")
        default:
            Issue.record("Expected title specifier")
        }
    }

    @Test("WindowSpecifier with index", .tags(.fast))
    func windowSpecifierIndex() {
        // Test window specifier with index
        let specifier = WindowSpecifier.index(0)

        switch specifier {
        case let .index(index):
            #expect(index == 0)
        default:
            Issue.record("Expected index specifier")
        }
    }

    // MARK: - Performance Tests

    @Test(
        "ApplicationListData encoding performance",
        arguments: [10, 50, 100, 200]
    )
    func applicationListEncodingPerformance(appCount: Int) throws {
        // Test performance of encoding many applications
        let apps = (0..<appCount).map { index in
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
        // Properties are already in snake_case, no conversion needed

        // Ensure encoding works correctly
        let data = try encoder.encode(appData)
        #expect(!data.isEmpty)
    }

    // MARK: - Window Count Display Tests

    @Test("printApplicationList hides window count when count is 1", .tags(.fast))
    func printApplicationListHidesWindowCountForSingleWindow() throws {
        // Create test applications with different window counts
        let applications = [
            ApplicationInfo(
                app_name: "Single Window App",
                bundle_id: "com.test.single",
                pid: 123,
                is_active: false,
                window_count: 1
            ),
            ApplicationInfo(
                app_name: "Multi Window App",
                bundle_id: "com.test.multi",
                pid: 456,
                is_active: true,
                window_count: 5
            ),
            ApplicationInfo(
                app_name: "No Windows App",
                bundle_id: "com.test.none",
                pid: 789,
                is_active: false,
                window_count: 0
            )
        ]

        // Get formatted output using the testable method
        let command = AppsSubcommand()
        let output = command.formatApplicationList(applications)

        // Verify that "Windows: 1" is NOT present for single window app
        #expect(!output.contains("Windows: 1"))

        // Verify that the single window app is listed but without window count
        #expect(output.contains("Single Window App"))

        // Verify that "Windows: 5" IS present for multi window app
        #expect(output.contains("Windows: 5"))

        // Verify that "Windows: 0" IS present for no windows app
        #expect(output.contains("Windows: 0"))
    }

    @Test("printApplicationList shows window count for non-1 values", .tags(.fast))
    func printApplicationListShowsWindowCountForNonSingleWindow() throws {
        let applications = [
            ApplicationInfo(
                app_name: "Zero Windows",
                bundle_id: "com.test.zero",
                pid: 100,
                is_active: false,
                window_count: 0
            ),
            ApplicationInfo(
                app_name: "Two Windows",
                bundle_id: "com.test.two",
                pid: 200,
                is_active: false,
                window_count: 2
            ),
            ApplicationInfo(
                app_name: "Many Windows",
                bundle_id: "com.test.many",
                pid: 300,
                is_active: false,
                window_count: 10
            )
        ]

        let command = AppsSubcommand()
        let output = command.formatApplicationList(applications)

        // All these should show window counts since they're not 1
        #expect(output.contains("Windows: 0"))
        #expect(output.contains("Windows: 2"))
        #expect(output.contains("Windows: 10"))
    }

    @Test("printApplicationList formats output correctly", .tags(.fast))
    func printApplicationListFormatsOutputCorrectly() throws {
        let applications = [
            ApplicationInfo(
                app_name: "Test App",
                bundle_id: "com.test.app",
                pid: 12345,
                is_active: true,
                window_count: 1
            )
        ]

        let command = AppsSubcommand()
        let output = command.formatApplicationList(applications)

        // Verify basic formatting is present
        #expect(output.contains("Running Applications (1):"))
        #expect(output.contains("1. Test App"))
        #expect(output.contains("Bundle ID: com.test.app"))
        #expect(output.contains("PID: 12345"))
        #expect(output.contains("Status: Active"))

        // Verify "Windows: 1" is NOT present
        #expect(!output.contains("Windows: 1"))
    }

    @Test("printApplicationList edge cases", .tags(.fast))
    func printApplicationListEdgeCases() throws {
        let applications = [
            ApplicationInfo(
                app_name: "Edge Case 1",
                bundle_id: "com.test.edge1",
                pid: 1,
                is_active: false,
                window_count: 1
            ),
            ApplicationInfo(
                app_name: "Edge Case 2",
                bundle_id: "com.test.edge2",
                pid: 2,
                is_active: true,
                window_count: 1
            )
        ]

        let command = AppsSubcommand()
        let output = command.formatApplicationList(applications)

        // Both apps have 1 window, so neither should show "Windows: 1"
        #expect(!output.contains("Windows: 1"))

        // But both apps should be listed
        #expect(output.contains("Edge Case 1"))
        #expect(output.contains("Edge Case 2"))
        #expect(output.contains("Status: Background"))
        #expect(output.contains("Status: Active"))
    }

    @Test("printApplicationList mixed window counts", .tags(.fast))
    func printApplicationListMixedWindowCounts() throws {
        let applications = [
            ApplicationInfo(app_name: "App A", bundle_id: "com.a", pid: 1, is_active: false, window_count: 0),
            ApplicationInfo(app_name: "App B", bundle_id: "com.b", pid: 2, is_active: false, window_count: 1),
            ApplicationInfo(app_name: "App C", bundle_id: "com.c", pid: 3, is_active: false, window_count: 2),
            ApplicationInfo(app_name: "App D", bundle_id: "com.d", pid: 4, is_active: false, window_count: 3)
        ]

        let command = AppsSubcommand()
        let output = command.formatApplicationList(applications)

        // Should show window counts for 0, 2, and 3, but NOT for 1
        #expect(output.contains("Windows: 0"))
        #expect(!output.contains("Windows: 1"))
        #expect(output.contains("Windows: 2"))
        #expect(output.contains("Windows: 3"))

        // All apps should be listed
        #expect(output.contains("App A"))
        #expect(output.contains("App B"))
        #expect(output.contains("App C"))
        #expect(output.contains("App D"))
    }
}

// MARK: - Extended List Command Tests

@Suite("ListCommand Advanced Tests", .tags(.integration))
struct ListCommandAdvancedTests {
    @Test("ServerStatusSubcommand parsing", .tags(.fast))
    func serverStatusSubcommandParsing() throws {
        let command = try ServerStatusSubcommand.parse([])
        #expect(command.jsonOutput == false)

        let commandWithJSON = try ServerStatusSubcommand.parse(["--json-output"])
        #expect(commandWithJSON.jsonOutput == true)
    }

    @Test("Command help messages", .tags(.fast))
    func commandHelpMessages() {
        let listHelp = ListCommand.helpMessage()
        #expect(listHelp.contains("List"))

        let appsHelp = AppsSubcommand.helpMessage()
        #expect(appsHelp.contains("running applications"))

        let windowsHelp = WindowsSubcommand.helpMessage()
        #expect(windowsHelp.contains("windows"))

        let statusHelp = ServerStatusSubcommand.helpMessage()
        #expect(statusHelp.contains("status"))
    }

    @Test(
        "Complex window info structures",
        arguments: [
            (title: "Main Window", id: 1001, onScreen: true),
            (title: "Hidden Window", id: 2001, onScreen: false),
            (title: "Minimized", id: 3001, onScreen: false)
        ]
    )
    func complexWindowInfo(title: String, id: UInt32, onScreen: Bool) throws {
        let windowInfo = WindowInfo(
            window_title: title,
            window_id: id,
            window_index: 0,
            bounds: nil,
            is_on_screen: onScreen
        )

        let encoder = JSONEncoder()
        // No need for convertToSnakeCase since properties are already in snake_case
        let data = try encoder.encode(windowInfo)

        let decoder = JSONDecoder()
        // No need for convertFromSnakeCase since properties are already in snake_case
        let decoded = try decoder.decode(WindowInfo.self, from: data)

        #expect(decoded.window_title == title)
        #expect(decoded.window_id == id)
        #expect(decoded.is_on_screen == onScreen)
    }

    @Test(
        "Application state combinations",
        arguments: [
            (active: true, windowCount: 5),
            (active: false, windowCount: 0),
            (active: true, windowCount: 0),
            (active: false, windowCount: 10)
        ]
    )
    func applicationStates(active: Bool, windowCount: Int) {
        let appInfo = ApplicationInfo(
            app_name: "TestApp",
            bundle_id: "com.test.app",
            pid: 1234,
            is_active: active,
            window_count: windowCount
        )

        #expect(appInfo.is_active == active)
        #expect(appInfo.window_count == windowCount)

        // Logical consistency checks
        if windowCount > 0 {
            // Apps with windows can be active or inactive
            #expect(appInfo.window_count > 0)
        }
    }

    @Test("Server permissions data encoding", .tags(.fast))
    func serverPermissionsEncoding() throws {
        let permissions = ServerPermissions(
            screen_recording: true,
            accessibility: false
        )

        let statusData = ServerStatusData(permissions: permissions)

        let encoder = JSONEncoder()
        // Properties are already in snake_case, no conversion needed
        let data = try encoder.encode(statusData)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let permsJson = json?["permissions"] as? [String: Any]

        #expect(permsJson?["screen_recording"] as? Bool == true)
        #expect(permsJson?["accessibility"] as? Bool == false)
    }
}
