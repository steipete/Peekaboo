//
//  VisualizerEventReceiver.swift
//  Peekaboo
//

@preconcurrency import Foundation
import os
import PeekabooCore
import PeekabooFoundation

@MainActor
final class VisualizerEventReceiver {
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "VisualizerEventReceiver")
    private let coordinator: VisualizerCoordinator
    private var observer: (any NSObjectProtocol)?
    private var cleanupTask: Task<Void, Never>?

    init(visualizerCoordinator: VisualizerCoordinator) {
        self.coordinator = visualizerCoordinator
        self.observer = DistributedNotificationCenter.default().addObserver(
            forName: .visualizerEventDispatched,
            object: nil,
            queue: .main)
        { [weak self] notification in
            guard let descriptor = notification.object as? String else {
                self?.logger.error("Visualizer notification missing identifier")
                return
            }

            Task { @MainActor [weak self] in
                await self?.handle(descriptor: descriptor)
            }
        }

        self.cleanupTask = Task.detached(priority: .background) {
            try? VisualizerEventStore.cleanup(olderThan: 600)
        }

        self.logger.info("Visualizer event receiver registered for distributed notifications")
    }

    @MainActor
    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        cleanupTask?.cancel()
    }

    private func handle(descriptor: String) async {
        guard let eventID = Self.parseEventID(from: descriptor) else {
            self.logger.error("Visualizer notification contained invalid identifier: \(descriptor, privacy: .public)")
            return
        }

        let event: VisualizerEvent
        do {
            event = try VisualizerEventStore.loadEvent(id: eventID)
        } catch {
            self.logger.error("Failed to load visualizer event \(eventID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }

        await self.execute(event: event)

        do {
            try VisualizerEventStore.removeEvent(id: eventID)
        } catch {
            self.logger.error("Failed to delete visualizer event \(eventID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func execute(event: VisualizerEvent) async {
        self.logger.debug("Processing visualizer event \(event.kind.rawValue, privacy: .public)")
        let success: Bool

        switch event.payload {
        case let .screenshotFlash(rect):
            success = await self.coordinator.showScreenshotFlash(in: rect)
        case let .clickFeedback(point, type):
            success = await self.coordinator.showClickFeedback(at: point, type: type)
        case let .typingFeedback(keys, duration):
            success = await self.coordinator.showTypingFeedback(keys: keys, duration: duration)
        case let .scrollFeedback(point, direction, amount):
            success = await self.coordinator.showScrollFeedback(at: point, direction: direction, amount: amount)
        case let .mouseMovement(from, to, duration):
            success = await self.coordinator.showMouseMovement(from: from, to: to, duration: duration)
        case let .swipeGesture(from, to, duration):
            success = await self.coordinator.showSwipeGesture(from: from, to: to, duration: duration)
        case let .hotkeyDisplay(keys, duration):
            success = await self.coordinator.showHotkeyDisplay(keys: keys, duration: duration)
        case let .appLaunch(name, iconPath):
            success = await self.coordinator.showAppLaunch(appName: name, iconPath: iconPath)
        case let .appQuit(name, iconPath):
            success = await self.coordinator.showAppQuit(appName: name, iconPath: iconPath)
        case let .windowOperation(operation, rect, duration):
            success = await self.coordinator.showWindowOperation(operation, windowRect: rect, duration: duration)
        case let .menuNavigation(path):
            success = await self.coordinator.showMenuNavigation(menuPath: path)
        case let .dialogInteraction(elementType, rect, action):
            success = await self.coordinator.showDialogInteraction(element: elementType, elementRect: rect, action: action)
        case let .spaceSwitch(from, to, direction):
            success = await self.coordinator.showSpaceSwitch(from: from, to: to, direction: direction)
        case let .elementDetection(elements, duration):
            success = await self.coordinator.showElementDetection(elements: elements, duration: duration)
        case let .annotatedScreenshot(imageData, elements, windowBounds, duration):
            success = await self.coordinator.showAnnotatedScreenshot(
                imageData: imageData,
                elements: elements,
                windowBounds: windowBounds,
                duration: duration)
        }

        if !success {
            self.logger.warning("Visualizer event \(event.kind.rawValue, privacy: .public) reported failure")
        }
    }

    private static func parseEventID(from descriptor: String) -> UUID? {
        descriptor.split(separator: "|", maxSplits: 1).first.flatMap { UUID(uuidString: String($0)) }
    }
}
