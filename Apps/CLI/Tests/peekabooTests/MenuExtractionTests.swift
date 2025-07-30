import Foundation
import Testing
@testable import peekaboo

@Suite("Menu Extraction Tests", .serialized)
struct MenuExtractionTests {
    @Test("Extract menu structure without clicking")
    func menuExtraction() async throws {
        // This test requires a running application
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else {
            Issue.record("Skipping local test - set RUN_LOCAL_TESTS=true to run")
            return
        }

        // Test with Calculator app
        let output = try await runPeekabooCommand(["menu", "list", "--app", "Calculator", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(JSONResponse.self, from: data)

        #expect(json.success == true)

        // Verify we got menu data
        if let menuData = json.data {
            let jsonData = try JSONSerialization.data(withJSONObject: menuData.value)
            let menus = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            #expect(menus?["app"] as? String == "Calculator")

            // Check for menu structure
            if let menuStructure = menus?["menu_structure"] as? [[String: Any]] {
                #expect(!menuStructure.isEmpty)

                // Verify common Calculator menus exist
                let menuTitles = menuStructure.compactMap { $0["title"] as? String }
                #expect(menuTitles.contains("Calculator"))
                #expect(menuTitles.contains("Edit"))
                #expect(menuTitles.contains("View"))
                #expect(menuTitles.contains("Window"))
                #expect(menuTitles.contains("Help"))

                // Check View menu has items
                if let viewMenu = menuStructure.first(where: { $0["title"] as? String == "View" }) {
                    #expect(viewMenu["enabled"] as? Bool == true)

                    if let items = viewMenu["items"] as? [[String: Any]] {
                        let itemTitles = items.compactMap { $0["title"] as? String }

                        // Calculator should have these view options
                        #expect(itemTitles.contains("Basic"))
                        #expect(itemTitles.contains("Scientific"))
                        #expect(itemTitles.contains("Programmer"))
                    }
                }
            }
        }
        #endif
    }

    @Test("Menu extraction includes keyboard shortcuts")
    func menuKeyboardShortcuts() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else {
            Issue.record("Skipping local test - set RUN_LOCAL_TESTS=true to run")
            return
        }

        // Test with TextEdit which has well-known shortcuts
        let output = try await runPeekabooCommand(["menu", "list", "--app", "TextEdit", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(JSONResponse.self, from: data)

        #expect(json.success == true)

        if let menuData = json.data {
            let jsonData = try JSONSerialization.data(withJSONObject: menuData.value)
            let menus = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            if let menuStructure = menus?["menu_structure"] as? [[String: Any]] {
                // Find File menu
                if let fileMenu = menuStructure.first(where: { $0["title"] as? String == "File" }),
                   let items = fileMenu["items"] as? [[String: Any]] {
                    // Check for New shortcut
                    if let newItem = items.first(where: { $0["title"] as? String == "New" }) {
                        #expect(newItem["shortcut"] as? String == "⌘N")
                    }

                    // Check for Save shortcut
                    if let saveItem = items.first(where: { ($0["title"] as? String)?.contains("Save") == true }) {
                        let shortcut = saveItem["shortcut"] as? String
                        #expect(shortcut == "⌘S" || shortcut == nil) // Save might not always have shortcut
                    }
                }
            }
        }
        #endif
    }

    @Test("Menu list-all extracts frontmost app menus")
    func menuListAll() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else {
            Issue.record("Skipping local test - set RUN_LOCAL_TESTS=true to run")
            return
        }

        let output = try await runPeekabooCommand(["menu", "list-all", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(JSONResponse.self, from: data)

        #expect(json.success == true)

        if let responseData = json.data {
            let jsonData = try JSONSerialization.data(withJSONObject: responseData.value)
            let result = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            if let apps = result?["apps"] as? [[String: Any]] {
                #expect(!apps.isEmpty)

                // Should have at least one app
                if let firstApp = apps.first {
                    #expect(firstApp["app_name"] != nil)
                    #expect(firstApp["bundle_id"] != nil)
                    #expect(firstApp["pid"] != nil)

                    if let menus = firstApp["menus"] as? [[String: Any]] {
                        #expect(!menus.isEmpty)

                        // Should have standard menus
                        let menuTitles = menus.compactMap { $0["title"] as? String }
                        #expect(menuTitles.contains("Apple")) // Apple menu is always present
                    }
                }
            }
        }
        #endif
    }

    @Test("Menu extraction handles nested submenus")
    func nestedSubmenus() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else {
            Issue.record("Skipping local test - set RUN_LOCAL_TESTS=true to run")
            return
        }

        // Finder has nested menus like View > Sort By > Name
        let output = try await runPeekabooCommand(["menu", "list", "--app", "Finder", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(JSONResponse.self, from: data)

        #expect(json.success == true)

        if let menuData = json.data {
            let jsonData = try JSONSerialization.data(withJSONObject: menuData.value)
            let menus = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            if let menuStructure = menus?["menu_structure"] as? [[String: Any]] {
                // Find View menu
                if let viewMenu = menuStructure.first(where: { $0["title"] as? String == "View" }),
                   let items = viewMenu["items"] as? [[String: Any]] {
                    // Look for submenu items
                    var hasSubmenu = false
                    for item in items {
                        if let subItems = item["items"] as? [[String: Any]], !subItems.isEmpty {
                            hasSubmenu = true
                            break
                        }
                    }

                    #expect(hasSubmenu, "Finder View menu should have submenus")
                }
            }
        }
        #endif
    }

    @Test("Menu extraction properly handles disabled items")
    func disabledMenuItems() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else {
            Issue.record("Skipping local test - set RUN_LOCAL_TESTS=true to run")
            return
        }

        let output = try await runPeekabooCommand(["menu", "list", "--app", "Finder", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(JSONResponse.self, from: data)

        #expect(json.success == true)

        if let menuData = json.data {
            let jsonData = try JSONSerialization.data(withJSONObject: menuData.value)
            let menus = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            if let menuStructure = menus?["menu_structure"] as? [[String: Any]] {
                var foundDisabledItem = false

                for menu in menuStructure {
                    if let items = menu["items"] as? [[String: Any]] {
                        for item in items {
                            if let enabled = item["enabled"] as? Bool, !enabled {
                                foundDisabledItem = true
                                break
                            }
                        }
                    }
                    if foundDisabledItem { break }
                }

                #expect(foundDisabledItem, "Should find at least one disabled menu item")
            }
        }
        #endif
    }
}

// MARK: - Test Helpers

private func runPeekabooCommand(_ args: [String]) async throws -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "./.build/debug/peekaboo")
    task.arguments = args

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    try task.run()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
