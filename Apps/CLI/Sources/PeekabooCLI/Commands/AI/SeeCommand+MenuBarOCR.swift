import CoreGraphics
import Foundation
import PeekabooCore

@MainActor
extension SeeCommand {
    func menuBarCandidateOCRMatcher(hints: [String]) -> MenuBarPopoverResolver.CandidateOCR {
        let selector = self.menuBarPopoverOCRSelector()
        return { candidate, _ in
            guard let match = try await selector.matchCandidate(
                windowID: CGWindowID(candidate.windowId),
                bounds: candidate.bounds,
                hints: hints
            )
            else { return nil }
            return MenuBarPopoverResolver.OCRMatch(
                captureResult: match.captureResult,
                bounds: match.bounds
            )
        }
    }

    func menuBarAreaOCRMatcher() -> MenuBarPopoverResolver.AreaOCR {
        let selector = self.menuBarPopoverOCRSelector()
        return { preferredX, hints in
            guard let match = try await selector.matchArea(preferredX: preferredX, hints: hints) else { return nil }
            return MenuBarPopoverResolver.OCRMatch(
                captureResult: match.captureResult,
                bounds: match.bounds
            )
        }
    }

    func captureMenuBarPopoverByArea(
        preferredX: CGFloat,
        hints: [String]
    ) async throws -> MenuBarPopoverCapture? {
        let matcher = self.menuBarAreaOCRMatcher()
        guard let match = try await matcher(preferredX, hints) else { return nil }
        guard let captureResult = match.captureResult,
              let bounds = match.bounds else {
            return nil
        }
        self.logger.verbose(
            "Selected menu bar popover via area capture",
            category: "Capture",
            metadata: [
                "rect": "\(bounds)"
            ]
        )
        return MenuBarPopoverCapture(
            captureResult: captureResult,
            windowBounds: bounds,
            windowId: nil
        )
    }

    func captureMenuBarPopoverFromOpenMenu(
        openExtra: MenuExtraInfo?,
        appHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        let ownerPID: pid_t? = {
            guard let openExtra else { return nil }
            return self.resolveMenuExtraOwnerPID(openExtra)
        }()
        let titles = [
            openExtra?.title,
            openExtra?.ownerName,
            openExtra?.rawTitle,
            appHint,
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

        for candidate in titles where !candidate.isEmpty {
            if let frame = try? await self.services.menu.menuExtraOpenMenuFrame(
                title: candidate,
                ownerPID: ownerPID
            ),
                let capture = try await self.captureMenuBarPopoverByFrame(
                    frame,
                    hint: appHint ?? openExtra?.title,
                    ownerHint: openExtra?.ownerName
                ) {
                return capture
            }
        }

        return nil
    }

    func ocrElements(imageData: Data, windowBounds: CGRect?) throws -> [DetectedElement] {
        guard let windowBounds else { return [] }
        let result = try OCRService().recognizeText(in: imageData)
        return ObservationOCRMapper.elements(from: result, windowBounds: windowBounds)
    }

    private func captureMenuBarPopoverByFrame(
        _ frame: CGRect,
        hint: String?,
        ownerHint: String?
    ) async throws -> MenuBarPopoverCapture? {
        let selector = self.menuBarPopoverOCRSelector()
        if let match = try await selector.matchFrame(
            frame,
            hints: MenuBarPopoverResolverContext.normalizedHints([hint, ownerHint])
        ) {
            self.logger.verbose(
                "Selected menu bar popover via AX menu frame",
                category: "Capture",
                metadata: [
                    "rect": "\(match.bounds)"
                ]
            )
            return MenuBarPopoverCapture(
                captureResult: match.captureResult,
                windowBounds: match.bounds,
                windowId: nil
            )
        }

        return nil
    }

    private func menuBarPopoverOCRSelector() -> ObservationMenuBarPopoverOCRSelector {
        ObservationMenuBarPopoverOCRSelector(
            screenCapture: self.services.screenCapture,
            screens: self.services.screens.listScreens()
        )
    }
}
