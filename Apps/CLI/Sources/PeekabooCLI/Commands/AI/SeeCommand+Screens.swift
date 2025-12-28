import AppKit
import AXorcist
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import ScreenCaptureKit

@MainActor
extension SeeCommand {
    func captureAllScreens() async throws -> [CaptureResult] {
        var results: [CaptureResult] = []

        // Get available displays from the screen capture service
        let content = try await SCShareableContent.current
        let displays = content.displays

        self.logger.info("Found \(displays.count) display(s) to capture")

        for (index, display) in displays.indexed() {
            self.logger.verbose("Capturing display \(index)", category: "MultiScreen", metadata: [
                "displayID": display.displayID,
                "width": display.width,
                "height": display.height
            ])

            do {
                let result = try await ScreenCaptureBridge.captureScreen(services: self.services, displayIndex: index)

                // Update path to include screen index if capturing multiple screens
                if displays.count > 1 {
                    let updatedResult = self.updateCaptureResultPath(result, screenIndex: index, displayInfo: display)
                    results.append(updatedResult)
                } else {
                    results.append(result)
                }
            } catch {
                self.logger.error("Failed to capture display \(index): \(error)")
                // Continue capturing other screens even if one fails
            }
        }

        if results.isEmpty {
            throw CaptureError.captureFailure("Failed to capture any screens")
        }

        return results
    }

    private func updateCaptureResultPath(
        _ result: CaptureResult,
        screenIndex: Int,
        displayInfo: SCDisplay
    ) -> CaptureResult {
        // Since CaptureResult is immutable and doesn't have a path property,
        // we can't update the path. Just return the original result.
        // The saved path is already included in result.savedPath if it was saved.
        result
    }

    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
