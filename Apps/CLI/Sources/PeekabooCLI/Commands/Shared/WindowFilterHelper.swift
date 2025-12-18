import PeekabooCore

enum WindowFilterHelper {
    /// Shared window filtering for capture/list flows. Keeps heuristics consistent across commands.
    static func filter(
        windows: [ServiceWindowInfo],
        appIdentifier: String,
        mode: WindowFiltering.Mode,
        logger: Logger?
    ) -> [ServiceWindowInfo] {
        let filtered = windows.filter { window in
            if let reason = WindowFiltering.disqualificationReason(for: window, mode: mode) {
                logger?.verbose(
                    "Skipping window",
                    metadata: [
                        "app": appIdentifier,
                        "title": window.title,
                        "index": window.index,
                        "reason": reason,
                    ]
                )
                return false
            }
            return true
        }

        return Self.deduplicate(
            windows: filtered,
            appIdentifier: appIdentifier,
            logger: logger
        )
    }

    private static func deduplicate(
        windows: [ServiceWindowInfo],
        appIdentifier: String,
        logger: Logger?
    ) -> [ServiceWindowInfo] {
        var seenWindowIDs = Set<Int>()
        var deduplicated: [ServiceWindowInfo] = []
        deduplicated.reserveCapacity(windows.count)

        for window in windows {
            guard seenWindowIDs.insert(window.windowID).inserted else {
                logger?.verbose(
                    "Skipping duplicate window",
                    metadata: [
                        "app": appIdentifier,
                        "title": window.title,
                        "windowID": window.windowID,
                        "index": window.index,
                        "layer": window.layer,
                    ]
                )
                continue
            }

            deduplicated.append(window)
        }

        return deduplicated
    }
}
