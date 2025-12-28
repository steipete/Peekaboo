import Algorithms
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
    func detectElements(
        imageData: Data,
        windowContext: WindowContext?
    ) async throws -> ElementDetectionResult {
        self.logger.operationStart("element_detection")
        defer { self.logger.operationComplete("element_detection") }

        do {
            return try await Self.withWallClockTimeout(seconds: 20.0) {
                try await AutomationServiceBridge.detectElements(
                    automation: self.services.automation,
                    imageData: imageData,
                    snapshotId: nil,
                    windowContext: windowContext
                )
            }
        } catch is TimeoutError {
            throw CaptureError.detectionTimedOut(20.0)
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

            if let appHint = self.menuBarAppHint() {
                self.logger.verbose("Attempting to open menu extra for capture", category: "Capture", metadata: [
                    "app": appHint
                ])
                let clickResult = try? await MenuServiceBridge.clickMenuBarItem(
                    named: appHint,
                    menu: self.services.menu
                )
                try? await Task.sleep(nanoseconds: 350_000_000)
                if let preferredX = clickResult?.location?.x,
                   let quickAreaCapture = try await self.captureMenuBarPopoverByArea(
                       preferredX: preferredX,
                       hints: MenuBarPopoverResolverContext.normalizedHints([appHint])
                   ) {
                    return CaptureContext(
                        captureResult: quickAreaCapture.captureResult,
                        captureBounds: quickAreaCapture.windowBounds,
                        prefersOCR: true,
                        ocrMethod: "OCR",
                        windowIdOverride: quickAreaCapture.windowId
                    )
                }
                if let popover = try await self.captureMenuBarPopover(allowAreaFallback: true) {
                    return CaptureContext(
                        captureResult: popover.captureResult,
                        captureBounds: popover.windowBounds,
                        prefersOCR: true,
                        ocrMethod: "OCR",
                        windowIdOverride: popover.windowId
                    )
                }
            }

            self.logger.verbose("No menu bar popover detected; capturing menu bar area", category: "Capture")
            let rect = try self.menuBarRect()
            let result = try await ScreenCaptureBridge.captureArea(services: self.services, rect: rect)
            return CaptureContext(
                captureResult: result,
                captureBounds: rect,
                prefersOCR: true,
                ocrMethod: "OCR",
                windowIdOverride: nil
            )
        }

        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                self.logger.verbose("Capturing menu bar area", category: "Capture")
                let rect = try self.menuBarRect()
                let result = try await ScreenCaptureBridge.captureArea(services: self.services, rect: rect)
                return CaptureContext(
                    captureResult: result,
                    captureBounds: rect,
                    prefersOCR: false,
                    ocrMethod: nil,
                    windowIdOverride: nil
                )
            case "frontmost":
                self.logger.verbose("Capturing frontmost window (via --app frontmost)", category: "Capture")
                let result = try await ScreenCaptureBridge.captureFrontmost(services: self.services)
                return CaptureContext(
                    captureResult: result,
                    captureBounds: nil,
                    prefersOCR: false,
                    ocrMethod: nil,
                    windowIdOverride: nil
                )
            default:
                let result = try await self.performStandardCapture()
                return CaptureContext(
                    captureResult: result,
                    captureBounds: nil,
                    prefersOCR: false,
                    ocrMethod: nil,
                    windowIdOverride: nil
                )
            }
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
                let result = try await ScreenCaptureBridge.captureWindowById(
                    services: self.services,
                    windowId: windowId
                )
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
                    let result = try await ScreenCaptureBridge.captureWindowById(
                        services: self.services,
                        windowId: resolvedWindowId
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
                let result = try await ScreenCaptureBridge.captureWindow(
                    services: self.services,
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
            let result = try await ScreenCaptureBridge.captureFrontmost(services: self.services)
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .area:
            throw ValidationError("Area capture mode is not supported for 'see' yet. Use --mode screen or window")
        }
    }
}
