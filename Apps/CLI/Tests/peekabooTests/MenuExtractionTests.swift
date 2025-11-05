import Foundation
import Testing
@testable import peekaboo

// Generic response structure for tests
struct MenuTestResponse: Codable {
    let success: Bool
    let data: MenuExtractionData?
    let error: String?
}

struct MenuExtractionData: Codable {
    let app: String?
    let menu_structure: [[String: Any]]?
    let apps: [[String: Any]]?

    enum CodingKeys: String, CodingKey {
        case app
        case menu_structure
        case apps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try container.decodeIfPresent(String.self, forKey: .app)

        // Decode as generic JSON
        if let menuStructure = try? container.decode([[String: AnyCodable]].self, forKey: .menu_structure) {
            self.menu_structure = menuStructure.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            self.menu_structure = nil
        }

        if let appsArray = try? container.decode([[String: AnyCodable]].self, forKey: .apps) {
            self.apps = appsArray.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            self.apps = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.app, forKey: .app)
        // For encoding, we'd need to convert back to AnyCodable
    }
}

// Helper for decoding arbitrary JSON
struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Simplified encoding
        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else {
            try container.encodeNil()
        }
    }
}

@Suite("Menu Extraction Tests", .serialized, .disabled("Requires local testing with RUN_LOCAL_TESTS"))
struct MenuExtractionTests {
    @Test("Extract menu structure without clicking")
    func menuExtraction() async throws {
        // This test requires a running application
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        // Test with Calculator app
        let output = try await runPeekabooCommand(["menu", "list", "--app", "Calculator", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(MenuTestResponse.self, from: data)

        #expect(json.success == true)

        // Verify we got menu data
        if let menuData = json.data {
            #expect(menuData.app == "Calculator")

            // Check for menu structure
            if let menuStructure = menuData.menu_structure {
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
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        // Test with TextEdit which has well-known shortcuts
        let output = try await runPeekabooCommand(["menu", "list", "--app", "TextEdit", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(MenuTestResponse.self, from: data)

        #expect(json.success == true)

        if let menuData = json.data as? [String: Any] {
            let jsonData = try JSONSerialization.data(withJSONObject: menuData)
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
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        let output = try await runPeekabooCommand(["menu", "list-all", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(MenuTestResponse.self, from: data)

        #expect(json.success == true)

        if let responseData = json.data as? [String: Any] {
            // json.data is already the data dictionary
            if let apps = responseData["apps"] as? [[String: Any]] {
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
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        // Finder has nested menus like View > Sort By > Name
        let output = try await runPeekabooCommand(["menu", "list", "--app", "Finder", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(MenuTestResponse.self, from: data)

        #expect(json.success == true)

        if let menuData = json.data {
            if let menuStructure = menuData.menu_structure {
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
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        let output = try await runPeekabooCommand(["menu", "list", "--app", "Finder", "--json-output"])
        let data = try #require(output.data(using: .utf8))
        let json = try JSONDecoder().decode(MenuTestResponse.self, from: data)

        #expect(json.success == true)

        if let menuData = json.data {
            if let menuStructure = menuData.menu_structure {
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
