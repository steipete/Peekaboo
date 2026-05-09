import AppKit
import CoreGraphics
import Foundation
import XCTest
@testable import PeekabooAutomationKit

@available(macOS 14.0, *)
@MainActor
final class ProcessServiceCaptureScriptTests: XCTestCase {
    func testScreenshotPathExpandsHomeDirectoryPath() async throws {
        let relativePath = "Library/Caches/peekaboo-script-shot-\(UUID().uuidString).png"
        let outputURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
        let tildePath = "~/\(relativePath)"
        let processService = ProcessService(
            applicationService: UnusedApplicationService(),
            screenCaptureService: StaticScreenCaptureService(),
            snapshotManager: InMemorySnapshotManager(),
            uiAutomationService: UnusedUIAutomationService(),
            windowManagementService: UnusedWindowManagementService(),
            menuService: UnusedMenuService(),
            dockService: UnusedDockService(),
            clipboardService: ClipboardService(pasteboard: NSPasteboard.withUniqueName()))
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let result = try await processService.executeStep(
            ScriptStep(stepId: "shot", comment: nil, command: "see", params: .screenshot(.init(
                path: tildePath,
                mode: "frontmost",
                annotate: false))),
            snapshotId: nil)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(try Data(contentsOf: outputURL), StaticScreenCaptureService.imageData)
        guard case let .data(output) = result.output else {
            return XCTFail("Expected structured output")
        }
        guard case let .success(screenshotPath)? = output["screenshot_path"] else {
            return XCTFail("Expected screenshot_path output")
        }
        XCTAssertEqual(screenshotPath, outputURL.path)
    }

    func testScreenshotPathCreatesParentDirectories() async throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-script-shot-\(UUID().uuidString)")
            .appendingPathComponent("nested")
            .appendingPathComponent("shot.png")
        let processService = ProcessService(
            applicationService: UnusedApplicationService(),
            screenCaptureService: StaticScreenCaptureService(),
            snapshotManager: InMemorySnapshotManager(),
            uiAutomationService: UnusedUIAutomationService(),
            windowManagementService: UnusedWindowManagementService(),
            menuService: UnusedMenuService(),
            dockService: UnusedDockService(),
            clipboardService: ClipboardService(pasteboard: NSPasteboard.withUniqueName()))
        defer {
            try? FileManager.default.removeItem(at: outputURL.deletingLastPathComponent().deletingLastPathComponent())
        }

        let result = try await processService.executeStep(
            ScriptStep(stepId: "shot", comment: nil, command: "see", params: .screenshot(.init(
                path: outputURL.path,
                mode: "frontmost",
                annotate: false))),
            snapshotId: nil)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(try Data(contentsOf: outputURL), StaticScreenCaptureService.imageData)
        guard case let .data(output) = result.output else {
            return XCTFail("Expected structured output")
        }
        guard case let .success(screenshotPath)? = output["screenshot_path"] else {
            return XCTFail("Expected screenshot_path output")
        }
        XCTAssertEqual(screenshotPath, outputURL.path)
    }
}

@available(macOS 14.0, *)
@MainActor
private final class StaticScreenCaptureService: ScreenCaptureServiceProtocol {
    static let imageData = Data("fake screenshot".utf8)

    func captureScreen(
        displayIndex _: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.result(mode: .screen)
    }

    func captureWindow(
        appIdentifier _: String,
        windowIndex _: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.result(mode: .window)
    }

    func captureFrontmost(
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.result(mode: .frontmost)
    }

    func captureArea(
        _: CGRect,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.result(mode: .area)
    }

    func hasScreenRecordingPermission() async -> Bool {
        true
    }

    private func result(mode: CaptureMode) -> CaptureResult {
        CaptureResult(
            imageData: Self.imageData,
            metadata: CaptureMetadata(size: CGSize(width: 1, height: 1), mode: mode))
    }
}
