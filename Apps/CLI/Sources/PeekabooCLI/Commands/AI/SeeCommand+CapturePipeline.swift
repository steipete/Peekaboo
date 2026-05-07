import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

@MainActor
extension SeeCommand {
    func detectElements(
        imageData: Data,
        windowContext: WindowContext?
    ) async throws -> ElementDetectionResult {
        self.logger.operationStart("element_detection")
        defer { self.logger.operationComplete("element_detection") }

        let timeoutSeconds = Self.detectionTimeoutSeconds(
            configuredTimeoutSeconds: self.timeoutSeconds,
            analyze: self.analyze
        )

        do {
            return try await Self.detectElements(
                automation: self.services.automation,
                imageData: imageData,
                windowContext: windowContext,
                timeoutSeconds: timeoutSeconds
            )
        } catch is TimeoutError {
            throw CaptureError.detectionTimedOut(timeoutSeconds)
        }
    }

    static func detectionTimeoutSeconds(
        configuredTimeoutSeconds: Int?,
        analyze: String?
    ) -> TimeInterval {
        TimeInterval(configuredTimeoutSeconds ?? ((analyze == nil) ? 20 : 60))
    }

    static func remoteDetectionRequestTimeoutSeconds(for timeoutSeconds: TimeInterval) -> TimeInterval {
        timeoutSeconds + 5
    }

    static func detectElements(
        automation: any UIAutomationServiceProtocol,
        imageData: Data,
        windowContext: WindowContext?,
        timeoutSeconds: TimeInterval
    ) async throws -> ElementDetectionResult {
        try await withWallClockTimeout(seconds: timeoutSeconds) {
            if let timeoutAdjustingAutomation = automation as? any DetectElementsRequestTimeoutAdjusting {
                return try await timeoutAdjustingAutomation.detectElements(
                    in: imageData,
                    snapshotId: nil,
                    windowContext: windowContext,
                    requestTimeoutSec: Self.remoteDetectionRequestTimeoutSeconds(for: timeoutSeconds)
                )
            }
            return try await AutomationServiceBridge.detectElements(
                automation: automation,
                imageData: imageData,
                snapshotId: nil,
                windowContext: windowContext
            )
        }
    }

    func resolveCaptureContext() async throws -> CaptureContext {
        if self.menubar {
            if let popover = try await self.captureMenuBarPopover() {
                return CaptureContext(
                    captureResult: popover.captureResult,
                    captureBounds: popover.windowBounds,
                    prefersOCR: true,
                    ocrMethod: "OCR",
                    windowIdOverride: popover.windowId
                )
            }

            self.logger.verbose("No menu bar popover detected; capturing menu bar area", category: "Capture")
            let rect = try self.menuBarRect()
            let result = try await self.services.screenCapture.captureArea(rect)
            return CaptureContext(
                captureResult: result,
                captureBounds: rect,
                prefersOCR: true,
                ocrMethod: "OCR",
                windowIdOverride: nil
            )
        }

        let result = try await self.performStandardCapture()
        return CaptureContext(
            captureResult: result,
            captureBounds: nil,
            prefersOCR: false,
            ocrMethod: nil,
            windowIdOverride: nil
        )
    }

    private func performStandardCapture() async throws -> CaptureResult {
        let effectiveMode = self.determineMode()
        self.logger.verbose(
            "Determined capture mode",
            category: "Capture",
            metadata: ["mode": effectiveMode.rawValue]
        )

        self.logger.operationStart("capture_phase", metadata: ["mode": effectiveMode.rawValue])
        switch effectiveMode {
        case .screen:
            // Handle screen capture with multi-screen support
            let result = try await self.performScreenCapture()
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .multi:
            // Commander currently treats multi captures as multi-display screen grabs
            let result = try await self.performScreenCapture()
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .window:
            if let windowId = self.windowId {
                self.logger.verbose("Initiating window capture (by id)", category: "Capture", metadata: [
                    "windowId": windowId,
                ])

                self.logger.startTimer("window_capture")
                let result = try await self.services.screenCapture.captureWindow(windowID: CGWindowID(windowId))
                self.logger.stopTimer("window_capture")
                self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
                return result
            } else if self.app != nil || self.pid != nil {
                let appIdentifier = try self.resolveApplicationIdentifier()
                self.logger.verbose("Initiating window capture", category: "Capture", metadata: [
                    "app": appIdentifier,
                    "windowTitle": self.windowTitle ?? "any",
                ])

                if let resolvedWindowId = try await self.resolveWindowId(
                    appIdentifier: appIdentifier,
                    titleFragment: self.windowTitle
                ) {
                    self.logger.verbose("Resolved window id for capture", category: "Capture", metadata: [
                        "windowId": resolvedWindowId
                    ])

                    self.logger.startTimer("window_capture")
                    let result = try await self.services.screenCapture.captureWindow(
                        windowID: CGWindowID(resolvedWindowId)
                    )
                    self.logger.stopTimer("window_capture")
                    self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
                    return result
                }

                let windowIndex = try await self.resolveSeeWindowIndex(
                    appIdentifier: appIdentifier,
                    titleFragment: self.windowTitle
                )

                self.logger.startTimer("window_capture")
                let result = try await self.services.screenCapture.captureWindow(
                    appIdentifier: appIdentifier,
                    windowIndex: windowIndex
                )
                self.logger.stopTimer("window_capture")
                self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
                return result
            } else {
                throw ValidationError("Provide --window-id, or --app/--pid for window mode")
            }

        case .frontmost:
            self.logger.verbose("Capturing frontmost window")
            let result = try await self.services.screenCapture.captureFrontmost()
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .area:
            throw ValidationError("Area capture mode is not supported for 'see' yet. Use --mode screen or window")
        }
    }
}
