import AppKit
import ArgumentParser
import Foundation
import Testing
import PeekabooCore
@testable import peekaboo

@Suite("PID Windows Subcommand Tests", .serialized)
struct PIDWindowsSubcommandTests {
    @Test("Parse windows subcommand with PID")
    func parseWindowsSubcommandWithPID() throws {
        // Test parsing windows subcommand with PID
        let command = try WindowsSubcommand.parse([
            "--app", "PID:1234",
            "--json-output",
        ])

        #expect(command.app == "PID:1234")
        #expect(command.jsonOutput == true)
    }

    @Test("Parse windows subcommand with PID and details")
    func parseWindowsSubcommandWithPIDAndDetails() throws {
        // Test windows subcommand with PID and window details
        let command = try WindowsSubcommand.parse([
            "--app", "PID:5678",
            "--include-details", "ids,bounds,off_screen",
            "--json-output",
        ])

        #expect(command.app == "PID:5678")
        #expect(command.includeDetails == "ids,bounds,off_screen")
        #expect(command.jsonOutput == true)
    }

    @Test("Various PID formats in windows subcommand")
    func variousPIDFormatsInWindowsSubcommand() throws {
        let pidFormats = [
            "PID:1", // Single digit
            "PID:123", // Three digits
            "PID:99999", // Large PID
        ]

        for pidFormat in pidFormats {
            let command = try WindowsSubcommand.parse([
                "--app", pidFormat,
            ])

            #expect(command.app == pidFormat)
        }
    }

    @Test("ApplicationInfo includes PID")
    func applicationInfoIncludesPID() throws {
        // Verify that ApplicationInfo includes PID
        let appInfo = ApplicationInfo(
            app_name: "TestApp",
            bundle_id: "com.test.app",
            pid: 1234,
            is_active: false,
            window_count: 2)

        #expect(appInfo.pid == 1234)
        #expect(appInfo.app_name == "TestApp")

        // Test JSON encoding includes PID
        let encoder = JSONEncoder()
        let data = try encoder.encode(appInfo)
        let json = String(data: data, encoding: .utf8) ?? ""

        #expect(json.contains("\"pid\":1234"))
    }

    @Test("TargetApplicationInfo includes PID")
    func targetApplicationInfoIncludesPID() throws {
        // Test that window list response includes target app PID
        let targetAppInfo = TargetApplicationInfo(
            app_name: "Safari",
            bundle_id: "com.apple.Safari",
            pid: 5678)

        #expect(targetAppInfo.pid == 5678)

        // Test JSON encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(targetAppInfo)
        let json = String(data: data, encoding: .utf8) ?? ""

        #expect(json.contains("\"pid\":5678"))
    }

    @Test("WindowListData structure with PID")
    func windowListDataStructureWithPID() throws {
        let targetAppInfo = TargetApplicationInfo(
            app_name: "Terminal",
            bundle_id: "com.apple.Terminal",
            pid: 9999)

        let windowInfo = WindowInfo(
            window_title: "~/Projects",
            window_id: 456,
            window_index: 0,
            bounds: nil,
            is_on_screen: true)

        let windowListData = WindowListData(
            windows: [windowInfo],
            target_application_info: targetAppInfo)

        #expect(windowListData.target_application_info.pid == 9999)
        #expect(windowListData.windows.count == 1)
    }
}
