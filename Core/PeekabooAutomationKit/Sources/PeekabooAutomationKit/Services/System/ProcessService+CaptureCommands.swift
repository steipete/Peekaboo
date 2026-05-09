import Foundation
import PeekabooFoundation

@MainActor
extension ProcessService {
    func executeSeeCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
        let params = self.screenshotParameters(from: step)
        let captureResult = try await self.captureScreenshot(using: params)
        let screenshotPath = try self.saveScreenshot(
            captureResult,
            to: params.path)
        let resolvedSnapshotId = try await self.storeScreenshot(
            captureResult: captureResult,
            path: screenshotPath,
            existingSnapshotId: snapshotId)

        try await self.annotateIfNeeded(
            shouldAnnotate: params.annotate ?? true,
            captureResult: captureResult,
            snapshotId: resolvedSnapshotId)

        return StepExecutionResult(
            output: .data([
                "snapshot_id": .success(resolvedSnapshotId),
                "screenshot_path": .success(screenshotPath),
            ]),
            snapshotId: resolvedSnapshotId)
    }

    private func screenshotParameters(from step: ScriptStep) -> ProcessCommandParameters.ScreenshotParameters {
        if case let .screenshot(params) = step.params {
            return params
        }
        return ProcessCommandParameters.ScreenshotParameters(path: "screenshot.png")
    }

    private func captureScreenshot(using params: ProcessCommandParameters
        .ScreenshotParameters) async throws -> CaptureResult
    {
        let mode = params.mode ?? "window"
        switch mode {
        case "fullscreen":
            return try await self.screenCaptureService.captureScreen(displayIndex: nil)
        case "frontmost":
            return try await self.screenCaptureService.captureFrontmost()
        case "window":
            if let appName = params.app {
                let windowIndex = params.window.flatMap(Int.init)
                return try await self.screenCaptureService.captureWindow(
                    appIdentifier: appName,
                    windowIndex: windowIndex)
            }
            return try await self.screenCaptureService.captureFrontmost()
        default:
            return try await self.screenCaptureService.captureFrontmost()
        }
    }

    private func saveScreenshot(
        _ captureResult: CaptureResult,
        to outputPath: String) throws -> String
    {
        guard !outputPath.isEmpty else {
            return captureResult.savedPath ?? ""
        }
        let resolvedPath = PathResolver.expandPath(outputPath)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: resolvedPath).deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try captureResult.imageData.write(to: URL(fileURLWithPath: resolvedPath))
        return resolvedPath
    }

    private func storeScreenshot(
        captureResult: CaptureResult,
        path: String,
        existingSnapshotId: String?) async throws -> String
    {
        let snapshotIdentifier: String = if let existingSnapshotId {
            existingSnapshotId
        } else {
            try await self.snapshotManager.createSnapshot()
        }
        try await self.persistScreenshot(
            captureResult: captureResult,
            path: path,
            snapshotId: snapshotIdentifier)
        return snapshotIdentifier
    }

    private func persistScreenshot(
        captureResult: CaptureResult,
        path: String,
        snapshotId: String) async throws
    {
        let appInfo = captureResult.metadata.applicationInfo
        let windowInfo = captureResult.metadata.windowInfo
        try await self.snapshotManager.storeScreenshot(
            SnapshotScreenshotRequest(
                snapshotId: snapshotId,
                screenshotPath: path,
                applicationBundleId: appInfo?.bundleIdentifier,
                applicationProcessId: appInfo.map { Int32($0.processIdentifier) },
                applicationName: appInfo?.name,
                windowTitle: windowInfo?.title,
                windowBounds: windowInfo?.bounds))
    }

    private func annotateIfNeeded(
        shouldAnnotate: Bool,
        captureResult: CaptureResult,
        snapshotId: String) async throws
    {
        guard shouldAnnotate else { return }
        let detectionResult = try await uiAutomationService.detectElements(
            in: captureResult.imageData,
            snapshotId: snapshotId,
            windowContext: nil)
        try await self.snapshotManager.storeDetectionResult(
            snapshotId: snapshotId,
            result: detectionResult)
    }
}
