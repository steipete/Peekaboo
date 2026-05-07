import Foundation
import PeekabooCore

@MainActor
extension SeeCommand {
    func captureAllScreens() async throws -> [CaptureResult] {
        var results: [CaptureResult] = []

        let displays = self.services.screens.listScreens()

        self.logger.info("Found \(displays.count) display(s) to capture")

        for display in displays {
            self.logger.verbose("Capturing display \(display.index)", category: "MultiScreen", metadata: [
                "displayID": display.displayID,
                "width": display.frame.width,
                "height": display.frame.height
            ])

            do {
                let result = try await ScreenCaptureBridge.captureScreen(
                    services: self.services,
                    displayIndex: display.index
                )
                results.append(result)
            } catch {
                self.logger.error("Failed to capture display \(display.index): \(error)")
                // Continue capturing other screens even if one fails
            }
        }

        if results.isEmpty {
            throw CaptureError.captureFailure("Failed to capture any screens")
        }

        return results
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
