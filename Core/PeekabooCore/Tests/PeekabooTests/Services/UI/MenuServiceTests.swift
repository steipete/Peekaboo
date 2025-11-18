//
//  MenuServiceTests.swift
//  PeekabooCore
//

import CoreGraphics
import Foundation
import os
import PeekabooFoundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("Menu Service Extras", .tags(.safe))
struct MenuServiceTests {
    @Test("Fallback/window extras replace placeholder AX names")
    @MainActor
    func fallbackReplacesPlaceholder() async {
        let accessible = [
            MenuExtraInfo(
                title: "Item-0",
                rawTitle: "Item-0",
                position: CGPoint(x: 120, y: 0)),
        ]
        let fallback = [
            MenuExtraInfo(
                title: "Control Center",
                rawTitle: "Control Center",
                bundleIdentifier: "com.apple.controlcenter",
                ownerName: "Control Center",
                position: CGPoint(x: 121, y: 0)),
        ]

        let merged = MenuService.mergeMenuExtras(accessibilityExtras: accessible, fallbackExtras: fallback)

        #expect(merged.count == 1)
        #expect(merged[0].title == "Control Center")
        #expect(merged[0].bundleIdentifier == "com.apple.controlcenter")
    }

    @Test("Rich accessibility titles still win when fallback is generic")
    @MainActor
    func accessibilityStillWins() async {
        let accessible = [
            MenuExtraInfo(
                title: "Wi-Fi",
                rawTitle: "WiFi",
                position: CGPoint(x: 50, y: 0)),
        ]
        let fallback = [
            MenuExtraInfo(
                title: "Item-0",
                rawTitle: "Item-0",
                position: CGPoint(x: 49.5, y: 0)),
        ]

        let merged = MenuService.mergeMenuExtras(accessibilityExtras: accessible, fallbackExtras: fallback)

        #expect(merged.count == 1)
        #expect(merged[0].title == "Wi-Fi")
    }

    @Test("Metadata merges when sources contribute different fields")
    @MainActor
    func metadataMergesAcrossSources() async {
        let accessible = [
            MenuExtraInfo(
                title: "Item-2",
                rawTitle: "Item-2",
                bundleIdentifier: "com.apple.controlcenter",
                ownerName: "Control Center",
                position: CGPoint(x: 200, y: 0)),
        ]
        let fallback = [
            MenuExtraInfo(
                title: "Battery",
                rawTitle: "Battery",
                position: CGPoint(x: 200.8, y: 0)),
        ]

        let merged = MenuService.mergeMenuExtras(accessibilityExtras: accessible, fallbackExtras: fallback)

        #expect(merged.count == 1)
        #expect(merged[0].title == "Battery")
        #expect(merged[0].bundleIdentifier == "com.apple.controlcenter")
        #expect(merged[0].ownerName == "Control Center")
    }

    @Test("Distinct extras remain sorted by X position")
    @MainActor
    func sortedByPosition() async {
        let accessible = [
            MenuExtraInfo(title: "Wi-Fi", position: CGPoint(x: 50, y: 0)),
            MenuExtraInfo(title: "Bluetooth", position: CGPoint(x: 150, y: 0)),
        ]
        let fallback: [MenuExtraInfo] = []

        let merged = MenuService.mergeMenuExtras(accessibilityExtras: accessible, fallbackExtras: fallback)

        #expect(merged.count == 2)
        #expect(merged[0].title == "Wi-Fi")
        #expect(merged[1].title == "Bluetooth")
        #expect(merged[0].position.x < merged[1].position.x)
    }

    @Test("Control Center identifier mapping overrides placeholder labels")
    func identifierMappingOverridesPlaceholder() {
        let lookup = ControlCenterIdentifierLookup(mapping: [
            "2D61E17B-1FC1-41CA-945C-975B98812617": "Stage Manager",
        ])

        #expect(humanReadableMenuIdentifier("2d61e17b-1fc1-41ca-945c-975b98812617", lookup: lookup) == "Stage Manager")
        #expect(humanReadableMenuIdentifier("bb3cc23c-6950-4e96-8b40-850e09f46934", lookup: lookup) == nil)
    }

    @Test("Fallback display names prefer owner names when raw title is a GUID")
    @MainActor
    func fallbackFriendlyTitleUsesOwner() async {
        let service = MenuService()
        let owner = "Control Center"
        let guid = "bb3cc23c-6950-4e96-8b40-850e09f46934"
        let friendly = await service.makeDebugDisplayName(
            rawTitle: guid,
            ownerName: owner,
            bundleIdentifier: "com.apple.controlcenter")
        #expect(friendly == owner)
    }

    @Test("Menu bar display titles append index when fallback uses owner")
    @MainActor
    func displayTitleAppendsIndexForOwnerFallback() async {
        let service = MenuService()
        let placeholderExtra = MenuExtraInfo(
            title: "Control Center",
            rawTitle: "Item-0",
            bundleIdentifier: "com.apple.controlcenter",
            ownerName: "Control Center",
            position: .zero,
            isVisible: true,
            identifier: nil)

        let displayTitle = service.resolvedMenuBarTitle(for: placeholderExtra, index: 5)
        #expect(displayTitle == "Control Center #5")
    }

    @Test("Fallback uses generic label when owner/title unavailable")
    @MainActor
    func genericIndexFallback() async {
        let service = MenuService()
        let placeholderExtra = MenuExtraInfo(
            title: "",
            rawTitle: "",
            bundleIdentifier: nil,
            ownerName: nil,
            position: .zero,
            isVisible: true,
            identifier: nil)

        let displayTitle = service.resolvedMenuBarTitle(for: placeholderExtra, index: 2)
        #expect(displayTitle == "Menu Bar Item #2")
    }

    @Test("Traversal budget caps children")
    func traversalBudgetChildCap() {
        var budget = MenuTraversalBudget(limits: .init(maxDepth: 4, maxChildren: 2, timeBudget: 5))

        let logger = Logger(subsystem: "test", category: "menu")
        let first = budget.allowVisit(depth: 1, logger: logger, context: "a")
        let second = budget.allowVisit(depth: 1, logger: logger, context: "b")
        let third = budget.allowVisit(depth: 1, logger: logger, context: "c")

        #expect(first)
        #expect(second)
        #expect(third == false)
    }

    @Test("Traversal budget caps time")
    func traversalBudgetTimeCap() async throws {
        var budget = MenuTraversalBudget(limits: .init(maxDepth: 4, maxChildren: 10, timeBudget: 0.001))
        let logger = Logger(subsystem: "test", category: "menu")

        let firstAllowed = budget.allowVisit(depth: 1, logger: logger, context: "start")
        #expect(firstAllowed)
        try await Task.sleep(nanoseconds: 2_000_000)
        let secondAllowed = budget.allowVisit(depth: 1, logger: logger, context: "later")
        #expect(secondAllowed == false)
    }

    @Test("Normalized title matching ignores diacritics and whitespace")
    func normalizedTitleMatching() {
        let target = "  Résumé  "
        #expect(titlesMatch(candidate: "resume", target: target))
        #expect(titlesMatch(candidate: "Résumé", target: target))
        #expect(titlesMatchPartial(candidate: "My Resume", target: target))
        #expect(titlesMatch(candidate: "Résumé", target: "resume"))
    }

    @Test("Normalized title strips accelerators and ellipsis")
    func normalizedTitleStripsAccelerators() {
        let target = "&File…"
        #expect(titlesMatch(candidate: "File...", target: target))
        #expect(titlesMatch(candidate: "file", target: target))
        #expect(titlesMatchPartial(candidate: "Recent File", target: target))
    }

    @Test("Placeholder detection catches GUIDs and numbers")
    func placeholderDetection() {
        #expect(isPlaceholderMenuTitle("12345"))
        #expect(isPlaceholderMenuTitle("bb3cc23c-6950-4e96-8b40-850e09f46934"))
        #expect(isPlaceholderMenuTitle("Menu Item"))
        #expect(isPlaceholderMenuTitle("Wi-Fi") == false)
    }

    @Test("Traversal limits from policy")
    func traversalLimitPolicy() {
        let balanced = MenuTraversalLimits.from(policy: .balanced)
        let debug = MenuTraversalLimits.from(policy: .debug)
        #expect(balanced.maxDepth < debug.maxDepth)
        #expect(balanced.maxChildren < debug.maxChildren)
        #expect(balanced.timeBudget < debug.timeBudget)
    }

    @Test("Menu cache returns within TTL")
    @MainActor
    func menuCacheReturnsWithinTTL() async throws {
        @MainActor
        final class FakeAppService: ApplicationServiceProtocol {
            let app: ServiceApplicationInfo
            private(set) var lookups = 0

            init(app: ServiceApplicationInfo) {
                self.app = app
            }

            func launchApplication(identifier: String) async throws -> ServiceApplicationInfo { self.app }
            func activateApplication(identifier: String) async throws {}
            func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
                UnifiedToolOutput(
                    data: ServiceApplicationListData(applications: [self.app]),
                    summary: .init(brief: "stub", status: .success),
                    metadata: .init(duration: 0))
            }

            func getFrontmostApplication() async throws -> ServiceApplicationInfo { self.app }
            func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
                self.lookups += 1
                return self.app
            }

            func getRunningApplications() async throws -> [ServiceApplicationInfo] { [self.app] }
            func listWindows(
                for appIdentifier: String,
                timeout: Float?) async throws -> UnifiedToolOutput<ServiceWindowListData>
            {
                UnifiedToolOutput(
                    data: ServiceWindowListData(windows: [], targetApplication: self.app),
                    summary: .init(brief: "stub", status: .success),
                    metadata: .init(duration: 0))
            }

            func isApplicationRunning(identifier: String) async -> Bool { true }
            func quitApplication(identifier: String, force: Bool) async throws -> Bool { true }
            func hideApplication(identifier: String) async throws {}
            func unhideApplication(identifier: String) async throws {}
            func hideOtherApplications(identifier: String) async throws {}
            func showAllApplications() async throws {}
        }

        let app = ServiceApplicationInfo(
            processIdentifier: 1234,
            bundleIdentifier: "com.test.app",
            name: "TestApp",
            bundlePath: nil,
            isActive: true,
            isHidden: false,
            windowCount: 0)

        let fakeService = FakeAppService(app: app)
        let service = MenuService(
            applicationService: fakeService,
            traversalPolicy: .balanced,
            logger: Logger(subsystem: "test", category: "menu"),
            visualizerClient: VisualizationClient.shared,
            partialMatchEnabled: true,
            cacheTTL: 5)

        // Seed cache manually to avoid AX dependency in unit test
        let cachedMenu = Menu(
            title: "File",
            bundleIdentifier: app.bundleIdentifier,
            ownerName: app.name,
            items: [],
            isEnabled: true)
        let cachedStructure = MenuStructure(application: app, menus: [cachedMenu])
        let appId = app.bundleIdentifier ?? "com.test.app"
        service.menuCache[appId] = (expiresAt: Date().addingTimeInterval(5), structure: cachedStructure)

        let result = try await service.listMenus(for: appId)

        #expect(result.menus.count == 1)
        #expect(result.menus.first?.title == "File")

        let lookupCount = await fakeService.lookups
        #expect(lookupCount == 0) // cache hit avoided lookup

        service.clearMenuCache()
    }
}
