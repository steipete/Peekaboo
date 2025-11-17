import PeekabooCore

enum WindowFilterHelper {
    /// Shared window filtering for capture/list flows. Keeps heuristics consistent across commands.
    static func filter(
        windows: [ServiceWindowInfo],
        appIdentifier: String,
        mode: WindowFiltering.Mode,
        logger: Logger?
    ) -> [ServiceWindowInfo] {
        windows.filter { window in
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
    }
}
