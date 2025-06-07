import ArgumentParser
@testable import peekaboo
import Testing
import Foundation

@Suite("ListCommand Tests", .tags(.unit))
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
    
    @Test("WindowsSubcommand detail parsing",
          arguments: [
              "off_screen",
              "bounds",
              "ids",
              "off_screen,bounds",
              "bounds,ids",
              "off_screen,bounds,ids"
          ])
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
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
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
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
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
            bounds: WindowBounds(xCoordinate: 100, yCoordinate: 200, width: 800, height: 600),
            is_on_screen: true
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let data = try encoder.encode(windowInfo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        #expect(json != nil)
        #expect(json?["window_title"] as? String == "Documents")
        #expect(json?["window_id"] as? UInt32 == 1001)
        #expect(json?["is_on_screen"] as? Bool == true)
        
        let bounds = json?["bounds"] as? [String: Any]
        #expect(bounds?["x_coordinate"] as? Int == 100)
        #expect(bounds?["y_coordinate"] as? Int == 200)
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
    
    @Test("ApplicationListData encoding performance",
          arguments: [10, 50, 100, 200])
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
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        // Ensure encoding works correctly
        let data = try encoder.encode(appData)
        #expect(data.count > 0)
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
    
    @Test("Complex window info structures",
          arguments: [
              (title: "Main Window", id: 1001, onScreen: true),
              (title: "Hidden Window", id: 2001, onScreen: false),
              (title: "Minimized", id: 3001, onScreen: false)
          ])
    func complexWindowInfo(title: String, id: UInt32, onScreen: Bool) throws {
        let windowInfo = WindowInfo(
            window_title: title,
            window_id: id,
            window_index: 0,
            bounds: nil,
            is_on_screen: onScreen
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(windowInfo)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(WindowInfo.self, from: data)
        
        #expect(decoded.window_title == title)
        #expect(decoded.window_id == id)
        #expect(decoded.is_on_screen == onScreen)
    }
    
    @Test("Application state combinations",
          arguments: [
              (active: true, windowCount: 5),
              (active: false, windowCount: 0),
              (active: true, windowCount: 0),
              (active: false, windowCount: 10)
          ])
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
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(statusData)
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let permsJson = json?["permissions"] as? [String: Any]
        
        #expect(permsJson?["screen_recording"] as? Bool == true)
        #expect(permsJson?["accessibility"] as? Bool == false)
    }
}