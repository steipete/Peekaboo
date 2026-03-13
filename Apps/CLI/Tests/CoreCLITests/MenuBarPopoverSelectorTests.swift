import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCLI

struct MenuBarPopoverSelectorTests {
    @Test
    func `prefers owner name match`() {
        let candidates = [
            MenuBarPopoverCandidate(
                windowId: 1,
                ownerPID: 100,
                bounds: CGRect(x: 10, y: 900, width: 200, height: 180)
            ),
            MenuBarPopoverCandidate(
                windowId: 2,
                ownerPID: 200,
                bounds: CGRect(x: 400, y: 900, width: 200, height: 180)
            ),
        ]

        let info: [Int: MenuBarPopoverWindowInfo] = [
            1: MenuBarPopoverWindowInfo(ownerName: "Screenshot", title: nil),
            2: MenuBarPopoverWindowInfo(ownerName: "Trimmy", title: nil),
        ]

        let selected = MenuBarPopoverSelector.selectCandidate(
            candidates: candidates,
            windowInfoById: info,
            preferredOwnerName: "Trimmy",
            preferredX: nil
        )

        #expect(selected?.windowId == 2)
    }

    @Test
    func `prefers nearest X when hint provided`() {
        let candidates = [
            MenuBarPopoverCandidate(
                windowId: 1,
                ownerPID: 100,
                bounds: CGRect(x: 10, y: 900, width: 200, height: 180)
            ),
            MenuBarPopoverCandidate(
                windowId: 2,
                ownerPID: 200,
                bounds: CGRect(x: 600, y: 900, width: 200, height: 180)
            ),
        ]

        let info: [Int: MenuBarPopoverWindowInfo] = [:]

        let selected = MenuBarPopoverSelector.selectCandidate(
            candidates: candidates,
            windowInfoById: info,
            preferredOwnerName: nil,
            preferredX: 120
        )

        #expect(selected?.windowId == 1)
    }

    @Test
    func `falls back to highest window when no hints`() {
        let candidates = [
            MenuBarPopoverCandidate(
                windowId: 1,
                ownerPID: 100,
                bounds: CGRect(x: 10, y: 800, width: 200, height: 180)
            ),
            MenuBarPopoverCandidate(
                windowId: 2,
                ownerPID: 200,
                bounds: CGRect(x: 400, y: 900, width: 200, height: 180)
            ),
        ]

        let info: [Int: MenuBarPopoverWindowInfo] = [:]

        let selected = MenuBarPopoverSelector.selectCandidate(
            candidates: candidates,
            windowInfoById: info,
            preferredOwnerName: nil,
            preferredX: nil
        )

        #expect(selected?.windowId == 2)
    }

    @Test
    func `ranks owner match ahead of X distance`() {
        let candidates = [
            MenuBarPopoverCandidate(
                windowId: 1,
                ownerPID: 100,
                bounds: CGRect(x: 10, y: 900, width: 200, height: 180)
            ),
            MenuBarPopoverCandidate(
                windowId: 2,
                ownerPID: 200,
                bounds: CGRect(x: 600, y: 900, width: 200, height: 180)
            ),
        ]

        let info: [Int: MenuBarPopoverWindowInfo] = [
            1: MenuBarPopoverWindowInfo(ownerName: "Trimmy", title: nil),
            2: MenuBarPopoverWindowInfo(ownerName: "Other", title: nil),
        ]

        let ranked = MenuBarPopoverSelector.rankCandidates(
            candidates: candidates,
            windowInfoById: info,
            preferredOwnerName: "Trimmy",
            preferredX: 580
        )

        #expect(ranked.first?.windowId == 1)
    }
}
