import CoreGraphics
import Foundation
import ImageIO
import PeekabooFoundation

extension LegacyScreenCaptureOperator {
    func captureWindowWithSystemScreencapture(
        windowID: CGWindowID,
        correlationId: String) throws -> CGImage
    {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peekaboo-window-\(windowID)-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // Match Apple's native window capture path; Hopper shows `screencapture -l` using
        // private window-id lookup before building its SCScreenshotManager content filter.
        process.arguments = [
            "-l",
            String(windowID),
            "-o",
            "-x",
            url.path,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw OperationError.captureFailed(reason: "screencapture exited with \(process.terminationStatus)")
        }

        let data = try Data(contentsOf: url)
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OperationError.captureFailed(reason: "Failed to decode screencapture output")
        }

        self.logger.debug(
            "Captured window via system screencapture",
            metadata: [
                "windowID": String(windowID),
                "imageSize": "\(image.width)x\(image.height)",
            ],
            correlationId: correlationId)
        return image
    }
}
