import CoreGraphics
import Foundation
import PeekabooCore

struct MenuBarPopoverResolution: Sendable {
    enum Reason: String, Sendable {
        case ownerPID = "owner_pid"
        case ownerName = "owner_name"
        case preferredX = "preferred_x"
        case ranked = "window_rank"
        case ocr
        case ocrArea = "ocr_area"
        case focusedWindow = "focused_window"
        case ownerWindow = "owner_pid_window"
        case axMenu = "ax_menu"
    }

    let windowId: Int?
    let bounds: CGRect?
    let confidence: Double
    let reason: Reason
    let captureResult: CaptureResult?
}

struct MenuBarPopoverResolverContext: Sendable {
    let appHint: String?
    let preferredOwnerName: String?
    let ownerPID: pid_t?
    let preferredX: CGFloat?
    let ocrHints: [String]

    static func normalizedHints(_ hints: [String?]) -> [String] {
        hints
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func build(
        appHint: String?,
        preferredOwnerName: String?,
        ownerPID: pid_t?,
        preferredX: CGFloat?,
        hints: [String?]
    ) -> MenuBarPopoverResolverContext {
        MenuBarPopoverResolverContext(
            appHint: appHint,
            preferredOwnerName: preferredOwnerName,
            ownerPID: ownerPID,
            preferredX: preferredX,
            ocrHints: self.normalizedHints(hints)
        )
    }
}

enum MenuBarPopoverResolver {
    struct OCRMatch: Sendable {
        let captureResult: CaptureResult?
        let bounds: CGRect?
    }

    typealias CandidateOCR = (MenuBarPopoverCandidate, MenuBarPopoverWindowInfo?) async throws -> OCRMatch?
    typealias AreaOCR = (CGFloat, [String]) async throws -> OCRMatch?

    struct ResolutionOptions {
        let allowOCR: Bool
        let allowAreaFallback: Bool
        let candidateOCR: CandidateOCR?
        let areaOCR: AreaOCR?
    }

    static func resolve(
        candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        context: MenuBarPopoverResolverContext,
        options: ResolutionOptions
    ) async throws -> MenuBarPopoverResolution? {
        guard !candidates.isEmpty else { return nil }

        if let ownerPID = context.ownerPID {
            let pidMatches = candidates.filter { $0.ownerPID == ownerPID }
            if let selected = selectCandidate(
                from: pidMatches,
                windowInfoById: windowInfoById,
                preferredOwnerName: context.preferredOwnerName,
                preferredX: context.preferredX
            ) {
                return MenuBarPopoverResolution(
                    windowId: selected.windowId,
                    bounds: selected.bounds,
                    confidence: 1.0,
                    reason: .ownerPID,
                    captureResult: nil
                )
            }
        }

        let ownerNameMatches = MenuBarPopoverSelector.filterByOwnerName(
            candidates: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: context.preferredOwnerName
        )
        if !ownerNameMatches.isEmpty,
           let selected = selectCandidate(
               from: ownerNameMatches,
               windowInfoById: windowInfoById,
               preferredOwnerName: nil,
               preferredX: context.preferredX
           ) {
            return MenuBarPopoverResolution(
                windowId: selected.windowId,
                bounds: selected.bounds,
                confidence: 0.9,
                reason: .ownerName,
                captureResult: nil
            )
        }

        if options.allowOCR,
           !context.ocrHints.isEmpty,
           let candidateOCR = options.candidateOCR {
            let ranked = MenuBarPopoverSelector.rankCandidates(
                candidates: candidates,
                windowInfoById: windowInfoById,
                preferredOwnerName: context.preferredOwnerName,
                preferredX: context.preferredX
            )
            for candidate in ranked.prefix(2) {
                if let match = try await candidateOCR(candidate, windowInfoById[candidate.windowId]) {
                    return MenuBarPopoverResolution(
                        windowId: candidate.windowId,
                        bounds: match.bounds ?? candidate.bounds,
                        confidence: 0.7,
                        reason: .ocr,
                        captureResult: match.captureResult
                    )
                }
            }
        }

        if options.allowAreaFallback,
           let preferredX = context.preferredX,
           let areaOCR = options.areaOCR {
            if let match = try await areaOCR(preferredX, context.ocrHints) {
                return MenuBarPopoverResolution(
                    windowId: nil,
                    bounds: match.bounds,
                    confidence: 0.5,
                    reason: .ocrArea,
                    captureResult: match.captureResult
                )
            }
        }

        if let selected = selectCandidate(
            from: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: context.preferredOwnerName,
            preferredX: context.preferredX
        ) {
            let reason: MenuBarPopoverResolution.Reason = context.preferredX != nil ? .preferredX : .ranked
            return MenuBarPopoverResolution(
                windowId: selected.windowId,
                bounds: selected.bounds,
                confidence: 0.4,
                reason: reason,
                captureResult: nil
            )
        }

        return nil
    }

    static func windowInfoById(from windowList: [[String: Any]]) -> [Int: MenuBarPopoverWindowInfo] {
        var info: [Int: MenuBarPopoverWindowInfo] = [:]
        for windowInfo in windowList {
            let windowId = windowInfo[kCGWindowNumber as String] as? Int ?? 0
            if windowId == 0 { continue }
            info[windowId] = MenuBarPopoverWindowInfo(
                ownerName: windowInfo[kCGWindowOwnerName as String] as? String,
                title: windowInfo[kCGWindowName as String] as? String
            )
        }
        return info
    }

    static func candidates(
        from windowList: [[String: Any]],
        screens: [MenuBarPopoverDetector.ScreenBounds],
        ownerPID: pid_t?
    ) -> [MenuBarPopoverCandidate] {
        MenuBarPopoverDetector.candidates(
            windowList: windowList,
            screens: screens,
            ownerPID: ownerPID
        )
    }

    private static func selectCandidate(
        from candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        preferredOwnerName: String?,
        preferredX: CGFloat?
    ) -> MenuBarPopoverCandidate? {
        MenuBarPopoverSelector.selectCandidate(
            candidates: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: preferredOwnerName,
            preferredX: preferredX
        )
    }
}
