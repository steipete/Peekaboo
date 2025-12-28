import AppKit
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension SeeCommand {
    func captureMenuBarPopoverByOCR(
        candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        hint: String,
        preferredOwnerName: String?,
        preferredX: CGFloat?
    ) async throws -> MenuBarPopoverCapture? {
        let normalized = hint.lowercased()
        let ranked = MenuBarPopoverSelector.rankCandidates(
            candidates: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: preferredOwnerName,
            preferredX: preferredX
        )
        for candidate in ranked {
            let captureResult = try await ScreenCaptureBridge.captureWindowById(
                services: self.services,
                windowId: candidate.windowId
            )
            guard let ocr = try? OCRService.recognizeText(in: captureResult.imageData) else { continue }
            let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
            if text.contains(normalized) {
                self.logger.verbose(
                    "Selected menu bar popover via OCR",
                    category: "Capture",
                    metadata: [
                        "windowId": candidate.windowId,
                        "hint": hint
                    ]
                )
                return MenuBarPopoverCapture(
                    captureResult: captureResult,
                    windowBounds: candidate.bounds,
                    windowId: candidate.windowId
                )
            }
        }
        return nil
    }

    func captureMenuBarPopoverByArea(
        preferredX: CGFloat,
        hint: String?,
        ownerHint: String?
    ) async throws -> MenuBarPopoverCapture? {
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

        let captureResult = try await ScreenCaptureBridge.captureArea(
            services: self.services,
            rect: rect
        )

        if let ocr = try? OCRService.recognizeText(in: captureResult.imageData),
           self.ocrMatchesHints(ocr, hint: hint, ownerHint: ownerHint) {
            self.logger.verbose(
                "Selected menu bar popover via area capture",
                category: "Capture",
                metadata: [
                    "rect": "\(rect)"
                ]
            )
            return MenuBarPopoverCapture(
                captureResult: captureResult,
                windowBounds: rect,
                windowId: nil
            )
        }

        return nil
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
        let result = try OCRService.recognizeText(in: imageData)
        return self.buildOCRElements(from: result, windowBounds: windowBounds)
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

        if let ocr = try? OCRService.recognizeText(in: captureResult.imageData),
           self.ocrMatchesHints(ocr, hint: hint, ownerHint: ownerHint) {
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

    private func ocrMatchesHints(
        _ ocr: OCRTextResult,
        hint: String?,
        ownerHint: String?
    ) -> Bool {
        let hints = [hint, ownerHint]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !hints.isEmpty else { return !ocr.observations.isEmpty }
        let text = ocr.observations.map(\.text).joined(separator: " ").lowercased()
        return hints.contains { hint in
            text.contains(hint.lowercased())
        }
    }

    private func buildOCRElements(from result: OCRTextResult, windowBounds: CGRect) -> [DetectedElement] {
        let minConfidence: Float = 0.3
        var elements: [DetectedElement] = []
        var index = 1

        for observation in result.observations where observation.confidence >= minConfidence {
            let rect = self.screenRect(
                from: observation.boundingBox,
                imageSize: result.imageSize,
                windowBounds: windowBounds
            )

            guard rect.width > 2, rect.height > 2 else { continue }

            let attributes = [
                "description": "ocr",
                "confidence": String(format: "%.2f", observation.confidence)
            ]

            elements.append(
                DetectedElement(
                    id: "ocr_\(index)",
                    type: .staticText,
                    label: observation.text,
                    value: nil,
                    bounds: rect,
                    isEnabled: true,
                    isSelected: nil,
                    attributes: attributes
                )
            )
            index += 1
        }

        return elements
    }

    private func screenRect(
        from normalizedBox: CGRect,
        imageSize: CGSize,
        windowBounds: CGRect
    ) -> CGRect {
        let width = normalizedBox.width * imageSize.width
        let height = normalizedBox.height * imageSize.height
        let x = normalizedBox.origin.x * imageSize.width
        let y = (1.0 - normalizedBox.origin.y - normalizedBox.height) * imageSize.height
        return CGRect(
            x: windowBounds.origin.x + x,
            y: windowBounds.origin.y + y,
            width: width,
            height: height
        )
    }
}
