import CoreGraphics
import Foundation

@MainActor
extension ScreenCaptureService {
    func captureScreenImpl(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let metadata: Metadata = ["displayIndex": displayIndex ?? "main"]
        let apis = self.fallbackRunner.apis(for: Self.captureEnginePreference)
        return try await self.performOperation(.screen, metadata: metadata) { correlationId in
            try await self.fallbackRunner.runCapture(
                operationName: CaptureOperation.screen.metricName,
                logger: self.logger,
                correlationId: correlationId,
                apis: apis)
            { api in
                switch api {
                case .modern:
                    try await self.modernOperator.captureScreen(
                        displayIndex: displayIndex,
                        correlationId: correlationId,
                        visualizerMode: visualizerMode,
                        scale: scale)
                case .legacy:
                    try await self.legacyOperator.captureScreen(
                        displayIndex: displayIndex,
                        correlationId: correlationId,
                        visualizerMode: visualizerMode,
                        scale: scale)
                }
            }
        }
    }

    func captureWindowImpl(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let metadata: Metadata = [
            "appIdentifier": appIdentifier,
            "windowIndex": windowIndex ?? "frontmost",
        ]

        return try await self.performOperation(.window, metadata: metadata) { correlationId in
            self.logger.debug(
                "Finding application",
                metadata: ["identifier": appIdentifier],
                correlationId: correlationId)
            let app = try await self.findApplication(matching: appIdentifier)
            self.logger.debug(
                "Found application",
                metadata: [
                    "name": app.name,
                    "pid": app.processIdentifier,
                    "bundleId": app.bundleIdentifier ?? "unknown",
                ],
                correlationId: correlationId)

            return try await self.captureWindow(
                app: app,
                windowIndex: windowIndex,
                options: WindowCaptureOptions(visualizerMode: visualizerMode, scale: scale),
                context: CaptureInvocationContext(operation: .window, correlationId: correlationId))
        }
    }

    func captureWindowImpl(
        windowID: CGWindowID,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let metadata: Metadata = [
            "windowID": Int(windowID),
        ]

        return try await self.performOperation(.window, metadata: metadata) { correlationId in
            try await self.captureWindow(
                windowID: windowID,
                options: WindowCaptureOptions(visualizerMode: visualizerMode, scale: scale),
                context: CaptureInvocationContext(operation: .window, correlationId: correlationId))
        }
    }

    func captureFrontmostImpl(
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        try await self.performOperation(.frontmost) { correlationId in
            let serviceApp = try await self.frontmostApplication()

            self.logger.debug(
                "Found frontmost application",
                metadata: [
                    "name": serviceApp.name,
                    "bundleId": serviceApp.bundleIdentifier ?? "none",
                    "pid": serviceApp.processIdentifier,
                ],
                correlationId: correlationId)

            return try await self.captureWindow(
                app: serviceApp,
                windowIndex: nil,
                options: WindowCaptureOptions(visualizerMode: visualizerMode, scale: scale),
                context: CaptureInvocationContext(operation: .frontmost, correlationId: correlationId))
        }
    }

    func captureAreaImpl(_ rect: CGRect, scale: CaptureScalePreference) async throws -> CaptureResult {
        let metadata: Metadata = [
            "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
        ]
        let apis = self.fallbackRunner.apis(for: Self.captureEnginePreference)

        return try await self.performOperation(.area, metadata: metadata) { correlationId in
            try await self.fallbackRunner.runCapture(
                operationName: CaptureOperation.area.metricName,
                logger: self.logger,
                correlationId: correlationId,
                apis: apis)
            { api in
                switch api {
                case .modern:
                    try await self.modernOperator.captureArea(
                        rect,
                        correlationId: correlationId,
                        scale: scale)
                case .legacy:
                    try await self.legacyOperator.captureArea(
                        rect,
                        correlationId: correlationId,
                        scale: scale)
                }
            }
        }
    }

    private func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        options: WindowCaptureOptions,
        context: CaptureInvocationContext) async throws -> CaptureResult
    {
        try await self.fallbackRunner.runCapture(
            operationName: context.operation.metricName,
            logger: self.logger,
            correlationId: context.correlationId,
            apis: self.fallbackRunner.apis(for: Self.captureEnginePreference))
        { api in
            switch api {
            case .modern:
                self.logger.debug(
                    "Using ScreenCaptureKit window capture path",
                    correlationId: context.correlationId)
                return try await self.modernOperator.captureWindow(
                    app: app,
                    windowIndex: windowIndex,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            case .legacy:
                self.logger.debug("Using legacy CGWindowList API", correlationId: context.correlationId)
                return try await self.legacyOperator.captureWindow(
                    app: app,
                    windowIndex: windowIndex,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            }
        }
    }

    private func captureWindow(
        windowID: CGWindowID,
        options: WindowCaptureOptions,
        context: CaptureInvocationContext) async throws -> CaptureResult
    {
        try await self.fallbackRunner.runCapture(
            operationName: context.operation.metricName,
            logger: self.logger,
            correlationId: context.correlationId,
            apis: self.fallbackRunner.apis(for: Self.captureEnginePreference))
        { api in
            switch api {
            case .modern:
                self.logger.debug(
                    "Using ScreenCaptureKit window-id capture path",
                    correlationId: context.correlationId)
                return try await self.modernOperator.captureWindow(
                    windowID: windowID,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            case .legacy:
                self.logger.debug(
                    "Using legacy CGWindowList API window-id capture path",
                    correlationId: context.correlationId)
                return try await self.legacyOperator.captureWindow(
                    windowID: windowID,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            }
        }
    }
}
