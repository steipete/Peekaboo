import AppKit
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension SeeCommand {
    func menuBarCandidateOCRMatcher(hints: [String]) -> MenuBarPopoverResolver.CandidateOCR {
        let normalized = hints.map { $0.lowercased() }
        return { candidate, _ in
            let captureResult = try await ScreenCaptureBridge.captureWindowById(
                services: self.services,
                windowId: candidate.windowId
            )
            guard let ocr = try? OCRService().recognizeText(in: captureResult.imageData) else { return nil }
            if ObservationOCRMapper.matches(ocr, hints: normalized) {
                return MenuBarPopoverResolver.OCRMatch(
                    captureResult: captureResult,
                    bounds: candidate.bounds
                )
            }
            return nil
        }
    }

    func menuBarAreaOCRMatcher() -> MenuBarPopoverResolver.AreaOCR {
        { preferredX, hints in
            guard let rect = self.menuBarPopoverAreaRect(preferredX: preferredX) else { return nil }
            let captureResult = try await ScreenCaptureBridge.captureArea(
                services: self.services,
                rect: rect
            )
            guard let ocr = try? OCRService().recognizeText(in: captureResult.imageData) else { return nil }
            if ObservationOCRMapper.matches(ocr, hints: hints) {
                return MenuBarPopoverResolver.OCRMatch(
                    captureResult: captureResult,
                    bounds: rect
                )
            }
            return nil
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
        let padded = frame.insetBy(dx: -8, dy: -8)
        guard let clamped = self.clampRectToScreens(padded) else { return nil }

        let captureResult = try await ScreenCaptureBridge.captureArea(
            services: self.services,
            rect: clamped
        )

        if let ocr = try? OCRService().recognizeText(in: captureResult.imageData),
           ObservationOCRMapper.matches(ocr, hints: MenuBarPopoverResolverContext.normalizedHints([hint, ownerHint])) {
            self.logger.verbose(
                "Selected menu bar popover via AX menu frame",
                category: "Capture",
                metadata: [
                    "rect": "\(clamped)"
                ]
            )
            return MenuBarPopoverCapture(
                captureResult: captureResult,
                windowBounds: clamped,
                windowId: nil
            )
        }

        return nil
    }

    private func menuBarPopoverAreaRect(preferredX: CGFloat) -> CGRect? {
        guard let screen = self.screenForMenuBarX(preferredX) else { return nil }
        let menuBarHeight = self.menuBarHeight(for: screen)
        let maxHeight = max(120, min(700, screen.frame.height - menuBarHeight))
        let width: CGFloat = 420
        let menuBarTop = screen.frame.maxY - menuBarHeight
        var rect = CGRect(
            x: preferredX - (width / 2.0),
            y: menuBarTop - maxHeight,
            width: width,
            height: maxHeight
        )
        rect.origin.x = max(screen.frame.minX, min(rect.origin.x, screen.frame.maxX - rect.width))
        rect.origin.y = max(screen.frame.minY, rect.origin.y)
        return rect
    }
}
