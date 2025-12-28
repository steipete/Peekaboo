import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCLI

@Suite("Menu bar popover resolver")
struct MenuBarPopoverResolverTests {
    private let candidates = [
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

    private let windowInfo: [Int: MenuBarPopoverWindowInfo] = [
        1: MenuBarPopoverWindowInfo(ownerName: "Trimmy", title: nil),
        2: MenuBarPopoverWindowInfo(ownerName: "Other", title: nil),
    ]

    @Test("prefers PID over OCR and area")
    func prefersPIDOverOCRAndArea() async throws {
        let context = MenuBarPopoverResolverContext(
            appHint: "Trimmy",
            preferredOwnerName: "Trimmy",
            ownerPID: 100,
            preferredX: nil,
            ocrHints: ["trimmy"]
        )

        let candidateOCR: MenuBarPopoverResolver.CandidateOCR = { candidate, _ in
            guard candidate.windowId == 2 else { return nil }
            return MenuBarPopoverResolver.OCRMatch(captureResult: nil, bounds: candidate.bounds)
        }

        let areaOCR: MenuBarPopoverResolver.AreaOCR = { _, _ in
            MenuBarPopoverResolver.OCRMatch(
                captureResult: nil,
                bounds: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        }

        let options = MenuBarPopoverResolver.ResolutionOptions(
            allowOCR: true,
            allowAreaFallback: true,
            candidateOCR: candidateOCR,
            areaOCR: areaOCR
        )
        let resolution = try await MenuBarPopoverResolver.resolve(
            candidates: self.candidates,
            windowInfoById: self.windowInfo,
            context: context,
            options: options
        )

        #expect(resolution?.reason == .ownerPID)
        #expect(resolution?.windowId == 1)
    }

    @Test("prefers owner name over OCR")
    func prefersOwnerNameOverOCR() async throws {
        let context = MenuBarPopoverResolverContext(
            appHint: "Trimmy",
            preferredOwnerName: "Trimmy",
            ownerPID: nil,
            preferredX: nil,
            ocrHints: ["trimmy"]
        )

        let candidateOCR: MenuBarPopoverResolver.CandidateOCR = { candidate, _ in
            guard candidate.windowId == 2 else { return nil }
            return MenuBarPopoverResolver.OCRMatch(captureResult: nil, bounds: candidate.bounds)
        }

        let options = MenuBarPopoverResolver.ResolutionOptions(
            allowOCR: true,
            allowAreaFallback: false,
            candidateOCR: candidateOCR,
            areaOCR: nil
        )
        let resolution = try await MenuBarPopoverResolver.resolve(
            candidates: self.candidates,
            windowInfoById: self.windowInfo,
            context: context,
            options: options
        )

        #expect(resolution?.reason == .ownerName)
        #expect(resolution?.windowId == 1)
    }

    @Test("prefers OCR over area")
    func prefersOCROverArea() async throws {
        let context = MenuBarPopoverResolverContext(
            appHint: nil,
            preferredOwnerName: nil,
            ownerPID: nil,
            preferredX: 120,
            ocrHints: ["hint"]
        )

        let candidateOCR: MenuBarPopoverResolver.CandidateOCR = { candidate, _ in
            guard candidate.windowId == 2 else { return nil }
            return MenuBarPopoverResolver.OCRMatch(captureResult: nil, bounds: candidate.bounds)
        }

        let areaOCR: MenuBarPopoverResolver.AreaOCR = { _, _ in
            MenuBarPopoverResolver.OCRMatch(
                captureResult: nil,
                bounds: CGRect(x: 50, y: 50, width: 120, height: 120)
            )
        }

        let options = MenuBarPopoverResolver.ResolutionOptions(
            allowOCR: true,
            allowAreaFallback: true,
            candidateOCR: candidateOCR,
            areaOCR: areaOCR
        )
        let resolution = try await MenuBarPopoverResolver.resolve(
            candidates: self.candidates,
            windowInfoById: self.windowInfo,
            context: context,
            options: options
        )

        #expect(resolution?.reason == .ocr)
        #expect(resolution?.windowId == 2)
    }

    @Test("falls back to area when OCR fails")
    func fallsBackToAreaWhenOCRFails() async throws {
        let context = MenuBarPopoverResolverContext(
            appHint: nil,
            preferredOwnerName: nil,
            ownerPID: nil,
            preferredX: 120,
            ocrHints: ["hint"]
        )

        let candidateOCR: MenuBarPopoverResolver.CandidateOCR = { _, _ in
            nil
        }

        let areaOCR: MenuBarPopoverResolver.AreaOCR = { _, _ in
            MenuBarPopoverResolver.OCRMatch(
                captureResult: nil,
                bounds: CGRect(x: 60, y: 60, width: 120, height: 120)
            )
        }

        let options = MenuBarPopoverResolver.ResolutionOptions(
            allowOCR: true,
            allowAreaFallback: true,
            candidateOCR: candidateOCR,
            areaOCR: areaOCR
        )
        let resolution = try await MenuBarPopoverResolver.resolve(
            candidates: self.candidates,
            windowInfoById: self.windowInfo,
            context: context,
            options: options
        )

        #expect(resolution?.reason == .ocrArea)
        #expect(resolution?.windowId == nil)
    }
}
