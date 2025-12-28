import CoreGraphics
import Foundation

struct MenuBarPopoverWindowInfo {
    let ownerName: String?
    let title: String?
}

enum MenuBarPopoverSelector {
    static func filterByOwnerName(
        candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        preferredOwnerName: String?
    ) -> [MenuBarPopoverCandidate] {
        guard let preferredOwnerName, !preferredOwnerName.isEmpty else { return [] }
        let normalized = preferredOwnerName.lowercased()
        let exact = candidates.filter { candidate in
            let ownerName = windowInfoById[candidate.windowId]?.ownerName?.lowercased()
            return ownerName == normalized
        }
        if !exact.isEmpty {
            return exact
        }

        let partial = candidates.filter { candidate in
            let ownerName = windowInfoById[candidate.windowId]?.ownerName?.lowercased() ?? ""
            return ownerName.contains(normalized)
        }
        return partial
    }

    static func rankCandidates(
        candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        preferredOwnerName: String?,
        preferredX: CGFloat?
    ) -> [MenuBarPopoverCandidate] {
        guard !candidates.isEmpty else { return [] }

        var filtered = candidates
        let ownerNameMatches = self.filterByOwnerName(
            candidates: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: preferredOwnerName
        )
        if !ownerNameMatches.isEmpty {
            filtered = ownerNameMatches
        }

        if let preferredX {
            return filtered.sorted { lhs, rhs in
                let lhsDistance = abs(lhs.bounds.midX - preferredX)
                let rhsDistance = abs(rhs.bounds.midX - preferredX)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.bounds.maxY > rhs.bounds.maxY
            }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.bounds.maxY != rhs.bounds.maxY {
                return lhs.bounds.maxY > rhs.bounds.maxY
            }
            let lhsArea = lhs.bounds.width * lhs.bounds.height
            let rhsArea = rhs.bounds.width * rhs.bounds.height
            return lhsArea > rhsArea
        }
    }

    static func selectCandidate(
        candidates: [MenuBarPopoverCandidate],
        windowInfoById: [Int: MenuBarPopoverWindowInfo],
        preferredOwnerName: String?,
        preferredX: CGFloat?
    ) -> MenuBarPopoverCandidate? {
        self.rankCandidates(
            candidates: candidates,
            windowInfoById: windowInfoById,
            preferredOwnerName: preferredOwnerName,
            preferredX: preferredX
        ).first
    }
}
