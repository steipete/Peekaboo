//
//  MenuServiceTests.swift
//  PeekabooCore
//

import CoreGraphics
import Testing
@testable import PeekabooCore

@Suite("Menu Service Extras", .tags(.safe))
struct MenuServiceTests {
    @Test("Accessibility extras take precedence over fallback heuristics")
    @MainActor
    func accessibilityExtrasWin() async {
        let accessible = [MenuExtraInfo(title: "Wi-Fi", position: CGPoint(x: 120, y: 0))]
        let fallback = [MenuExtraInfo(title: "Item-0", position: CGPoint(x: 120, y: 0))]

        let merged = MenuService.mergeMenuExtras(accessibilityExtras: accessible, fallbackExtras: fallback)

        #expect(merged.count == 1)
        #expect(merged[0].title == "Wi-Fi")
    }

    @Test("Fallback extras merge when they are distinct")
    @MainActor
    func fallbackExtrasAdded() async {
        let accessible = [MenuExtraInfo(title: "Wi-Fi", position: CGPoint(x: 50, y: 0))]
        let fallback = [MenuExtraInfo(title: "Bluetooth", position: CGPoint(x: 150, y: 0))]

        let merged = MenuService.mergeMenuExtras(accessibilityExtras: accessible, fallbackExtras: fallback)

        #expect(merged.count == 2)
        #expect(merged[0].title == "Wi-Fi")
        #expect(merged[1].title == "Bluetooth")
        #expect(merged[0].position.x < merged[1].position.x)
    }

    @Test("Duplicate fallback items are suppressed")
    @MainActor
    func fallbackDuplicatesFiltered() async {
        let accessible = [MenuExtraInfo(title: "Control Center", position: CGPoint(x: 30, y: 0))]
        let fallback = [MenuExtraInfo(title: "Item-1", position: CGPoint(x: 30, y: 0))]

        let merged = MenuService.mergeMenuExtras(accessibilityExtras: accessible, fallbackExtras: fallback)

        #expect(merged.count == 1)
        #expect(merged[0].title == "Control Center")
    }
}
