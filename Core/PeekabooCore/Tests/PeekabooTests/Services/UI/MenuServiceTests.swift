//
//  MenuServiceTests.swift
//  PeekabooCore
//

import CoreGraphics
import Testing
@testable import PeekabooCore

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
}
