import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

/// Core screenshot capture functionality using ScreenCaptureKit.
///
/// Provides methods to capture entire displays or specific windows using Apple's
/// modern ScreenCaptureKit framework for high-quality, efficient captures.
struct ScreenCapture: Sendable {
    static func captureDisplay(
        _ displayID: CGDirectDisplayID, to path: String, format: ImageFormat = .png
    ) async throws {
        // Use the screencapture command as a fallback
        // Note: screencapture uses 1-based display indices, not display IDs
        // We need to find the index of this display in the list of all displays
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, nil)

        let displayIndex = displays.firstIndex(of: displayID).map { $0 + 1 } ?? 1

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-D", "\(displayIndex)", path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw CaptureError.captureCreationFailed(
                    NSError(
                        domain: "ScreenCapture",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: errorString]
                    )
                )
            }

            // Verify the file was created
            guard FileManager.default.fileExists(atPath: path) else {
                throw CaptureError.captureCreationFailed(nil)
            }
        } catch {
            throw CaptureError.captureCreationFailed(error)
        }
    }

    static func captureWindow(_ window: WindowData, to path: String, format: ImageFormat = .png) async throws {
        // Use the screencapture command for window capture
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-l", "\(window.windowId)", path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw CaptureError.windowNotFound
            }

            // Verify the file was created
            guard FileManager.default.fileExists(atPath: path) else {
                throw CaptureError.windowNotFound
            }
        } catch {
            if error is CaptureError {
                throw error
            }
            throw CaptureError.captureCreationFailed(error)
        }
    }
}
