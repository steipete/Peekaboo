import AppKit
import Commander
import Foundation
import os
import PeekabooCore
import PeekabooFoundation
import PeekabooVisualizer

@MainActor
struct VisualizerCommand: RuntimeOptionsConfigurable {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "visualizer",
                abstract: "Exercise Peekaboo visual feedback animations",
                discussion: """
                Runs a lightweight smoke sequence that fires every visualizer event so you can verify
                Peekaboo.app is rendering overlays.
                """,
                showHelpOnEmptyInvocation: false
            )
        }
    }

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let logger = self.resolvedRuntime.logger
        logger.info("Starting visualizer smoke sequence")
        try await VisualizerSmokeSequence(logger: logger).run()
        logger.info("Visualizer smoke sequence finished")
    }
}

@MainActor
private struct VisualizerSmokeSequence {
    let logger: Logger

    func run() async throws {
        let client = VisualizationClient.shared
        client.connect()

        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let primaryRect = screenFrame.insetBy(dx: screenFrame.width * 0.25, dy: screenFrame.height * 0.25)
        let point = CGPoint(x: primaryRect.midX, y: primaryRect.midY)

        try await self.step("Screenshot flash") {
            await client.showScreenshotFlash(in: primaryRect)
        }

        try await self.step("Watch capture HUD") {
            await client.showWatchCapture(in: primaryRect)
        }

        try await self.step("Click ripple") {
            await client.showClickFeedback(at: point, type: .single)
        }

        try await self.step("Typing indicator") {
            await client.showTypingFeedback(keys: ["H", "i", "!"], duration: 1.5, cadence: .human(wordsPerMinute: 60))
        }

        try await self.step("Scroll indicator") {
            await client.showScrollFeedback(at: point, direction: .down, amount: 3)
        }

        try await self.step("Mouse movement trail") {
            await client.showMouseMovement(from: point, to: CGPoint(x: point.x + 180, y: point.y + 120), duration: 0.8)
        }

        try await self.step("Swipe gesture") {
            await client.showSwipeGesture(
                from: CGPoint(x: point.x - 120, y: point.y),
                to: CGPoint(x: point.x + 120, y: point.y),
                duration: 0.6
            )
        }

        try await self.step("Hotkey heads-up display") {
            await client.showHotkeyDisplay(keys: ["Cmd", "Shift", "T"], duration: 1.2)
        }

        try await self.step("Window move overlay") {
            await client.showWindowOperation(.move, windowRect: primaryRect, duration: 0.7)
        }

        try await self.step("App launch icon bounce") {
            await client.showAppLaunch(appName: "Visualizer Smoke Test", iconPath: nil)
        }

        try await self.step("App quit animation") {
            await client.showAppQuit(appName: "Visualizer Smoke Test", iconPath: nil)
        }

        try await self.step("Menu breadcrumb highlight") {
            await client.showMenuNavigation(menuPath: ["File", "New", "Window"])
        }

        try await self.step("Dialog interaction highlight") {
            await client.showDialogInteraction(
                element: .button,
                elementRect: CGRect(origin: point, size: CGSize(width: 160, height: 40)),
                action: .clickButton
            )
        }

        try await self.step("Space switch indicator") {
            await client.showSpaceSwitch(from: 1, to: 2, direction: .right)
        }

        try await self.step("Element detection overlay") {
            let sampleElements: [String: CGRect] = [
                "B1": CGRect(x: primaryRect.minX + 20, y: primaryRect.minY + 20, width: 140, height: 44),
                "T1": CGRect(x: primaryRect.midX - 80, y: primaryRect.midY, width: 200, height: 40)
            ]
            await client.showElementDetection(elements: sampleElements)
        }
    }

    private func step(_ name: String, action: @escaping @MainActor () async -> Void) async throws {
        self.logger.debug("VisualizerSmoke: \(name)")
        await action()
        try await Task.sleep(for: .milliseconds(250))
    }
}

extension VisualizerCommand: AsyncRuntimeCommand {}
