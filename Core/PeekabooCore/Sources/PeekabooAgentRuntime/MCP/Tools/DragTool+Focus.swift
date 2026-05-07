import Foundation
import os.log

extension DragTool {
    func focusTargetAppIfNeeded(request: DragRequest) async throws {
        guard request.autoFocus, let toApp = request.targetApp else { return }
        do {
            try await self.context.windows.focusWindow(target: .application(toApp))
            try await Task.sleep(nanoseconds: 100_000_000)
        } catch {
            self.logger.warning("Failed to focus target app '\(toApp)': \(error.localizedDescription)")
        }
    }

    func logSpaceIntentIfNeeded(request: DragRequest) {
        guard request.bringToCurrentSpace || request.spaceSwitch else { return }
        let message = """
        Space management requested (bring_to_current_space: \(request.bringToCurrentSpace), \
        space_switch: \(request.spaceSwitch))
        """
        self.logger.info("\(message)")
    }
}
