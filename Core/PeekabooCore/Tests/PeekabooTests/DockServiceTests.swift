import PeekabooAutomationKit
import Testing

@Suite(
    .tags(.automation, .requiresPermissions, .localOnly),
    .enabled(if: TestEnvironment.runAutomationScenarios))
@MainActor
struct DockServiceTests {
    @Test
    func `List dock items includes Finder and Trash`() async throws {
        let items = try await DockService().listDockItems(includeAll: false)

        let finder = try #require(items.first { $0.bundleIdentifier == "com.apple.finder" })
        #expect(finder.itemType == .application)
        #expect(finder.isRunning == true)
        #expect(items.contains { $0.itemType == .trash })
    }

    @Test
    func `Separators are listed only with includeAll`() async throws {
        let service = DockService()
        let items = try await service.listDockItems(includeAll: false)
        let allItems = try await service.listDockItems(includeAll: true)

        #expect(allItems.count >= items.count)
        #expect(!items.contains { $0.itemType == .separator })
    }

    @Test
    func `Dock item properties are valid`() async throws {
        let items = try await DockService().listDockItems(includeAll: true)

        for item in items {
            #expect(item.index >= 0)
            #expect(!item.title.isEmpty || item.itemType == .separator)
            if let size = item.size {
                #expect(size.width > 0)
                #expect(size.height > 0)
            }
        }
    }

    @Test
    func `Find dock item returns Finder`() async throws {
        let finder = try await DockService().findDockItem(name: "Finder")

        #expect(finder.itemType == .application)
        #expect(finder.isRunning == true)
        #expect(finder.bundleIdentifier == "com.apple.finder")
    }

    @Test
    func `Find dock item matches Finder case insensitively`() async throws {
        let finder = try await DockService().findDockItem(name: "finder")

        #expect(finder.itemType == .application)
        #expect(finder.bundleIdentifier == "com.apple.finder")
    }

    @Test
    func `Find nonexistent dock item throws item not found`() async throws {
        do {
            _ = try await DockService().findDockItem(name: "NonExistentApp12345")
            Issue.record("Expected DockError.itemNotFound")
        } catch {
            guard case let DockError.itemNotFound(name) = error else {
                Issue.record("Expected DockError.itemNotFound, got: \(error)")
                return
            }
            #expect(name == "NonExistentApp12345")
        }
    }
}
