import CoreGraphics
import PeekabooCore

enum ScreenCaptureBridge {
    static func captureFrontmost(services: any PeekabooServiceProviding) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureFrontmost()
        }.value
    }

    static func captureWindow(
        services: any PeekabooServiceProviding,
        appIdentifier: String,
        windowIndex: Int?
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureWindow(appIdentifier: appIdentifier, windowIndex: windowIndex)
        }.value
    }

    static func captureWindowById(
        services: any PeekabooServiceProviding,
        windowId: Int
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureWindow(windowID: CGWindowID(windowId))
        }.value
    }

    static func captureArea(services: any PeekabooServiceProviding, rect: CGRect) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureArea(rect)
        }.value
    }

    static func captureScreen(
        services: any PeekabooServiceProviding,
        displayIndex: Int?
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureScreen(displayIndex: displayIndex)
        }.value
    }
}
