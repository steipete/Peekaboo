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
                position: CGPoint(x: 120, y: 0))
        ]
        let fallback = [
            MenuExtraInfo(
                title: "Control Center",
                rawTitle: "Control Center",
                bundleIdentifier: "com.apple.controlcenter",
                ownerName: "Control Center",
                position: CGPoint(x: 121, y: 0))
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
                position: CGPoint(x: 50, y: 0))
        ]
        let fallback = [
            MenuExtraInfo(
                title: "Item-0",
                rawTitle: "Item-0",
                position: CGPoint(x: 49.5, y: 0))
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
                position: CGPoint(x: 200, y: 0))
        ]
        let fallback = [
            MenuExtraInfo(
                title: "Battery",
                rawTitle: "Battery",
                position: CGPoint(x: 200.8, y: 0))
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
}
