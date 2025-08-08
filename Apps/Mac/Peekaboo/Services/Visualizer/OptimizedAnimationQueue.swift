//
//  OptimizedAnimationQueue.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import AppKit
import CoreGraphics
import Foundation
import os

/// Optimized animation queue with batching and resource management
actor OptimizedAnimationQueue {
    // MARK: - Properties

    /// Logger
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "AnimationQueue")

    /// Maximum concurrent animations
    private let maxConcurrentAnimations = 5

    /// Animation batch interval (seconds)
    private let batchInterval: TimeInterval = 0.016 // ~60 FPS

    /// Currently running animations
    private var activeAnimations = Set<UUID>()

    /// Queued animations
    private var queuedAnimations: [QueuedAnimation] = []

    /// Batch timer task
    private var batchTimerTask: Task<Void, Never>?

    /// Performance monitor
    private nonisolated func getPerformanceMonitor() async -> PerformanceMonitor {
        await MainActor.run {
            PerformanceMonitor.shared
        }
    }

    /// Animation priorities
    enum Priority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Public Methods

    /// Enqueue an animation with priority
    func enqueue(
        priority: Priority = .normal,
        animation: @Sendable @escaping () async -> Bool) async -> Bool
    {
        let id = UUID()

        // Check if we can run immediately
        if self.activeAnimations.count < self.maxConcurrentAnimations, self.queuedAnimations.isEmpty {
            return await self.runAnimation(id: id, animation: animation)
        }

        // Otherwise queue it
        let queuedAnimation = QueuedAnimation(
            id: id,
            priority: priority,
            animation: animation)

        self.queuedAnimations.append(queuedAnimation)
        self.queuedAnimations.sort { $0.priority > $1.priority }

        // Start batch timer if needed
        self.startBatchTimerIfNeeded()

        // Wait for completion
        return await queuedAnimation.completion
    }

    /// Cancel all queued animations
    func cancelAll() {
        self.queuedAnimations.removeAll()
        self.logger.info("Cancelled all queued animations")
    }

    /// Get queue status
    func getStatus() -> (active: Int, queued: Int) {
        (self.activeAnimations.count, self.queuedAnimations.count)
    }

    // MARK: - Private Methods

    private func runAnimation(id: UUID, animation: @escaping () async -> Bool) async -> Bool {
        self.activeAnimations.insert(id)

        // Track performance
        let performanceMonitor = await getPerformanceMonitor()
        let tracker = await MainActor.run {
            performanceMonitor.recordAnimationStart(type: "Animation-\(id)")
        }

        let result = await animation()

        // Complete tracking
        await MainActor.run {
            performanceMonitor.recordAnimationComplete(tracker: tracker)
        }

        self.activeAnimations.remove(id)

        // Process next batch
        await self.processNextBatch()

        return result
    }

    private func startBatchTimerIfNeeded() {
        guard self.batchTimerTask == nil else { return }

        self.batchTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.batchInterval))
                if !Task.isCancelled {
                    await self.processBatch()
                }
            }
        }
    }

    private func processBatch() async {
        await self.processNextBatch()
    }

    private func processNextBatch() async {
        let availableSlots = self.maxConcurrentAnimations - self.activeAnimations.count
        guard availableSlots > 0 else { return }

        // Get next animations to run
        let animationsToRun = Array(queuedAnimations.prefix(availableSlots))
        self.queuedAnimations.removeFirst(min(availableSlots, self.queuedAnimations.count))

        // Run animations concurrently
        await withTaskGroup(of: Void.self) { group in
            for queued in animationsToRun {
                group.addTask { [weak self] in
                    guard let self else { return }
                    let result = await self.runAnimation(id: queued.id, animation: queued.animation)
                    queued.complete(with: result)
                }
            }
        }

        // Stop timer if queue is empty
        if self.queuedAnimations.isEmpty, self.activeAnimations.isEmpty {
            self.batchTimerTask?.cancel()
            self.batchTimerTask = nil
        }
    }

    // MARK: - Nested Types

    /// Queued animation data
    private final class QueuedAnimation: @unchecked Sendable {
        let id: UUID
        let priority: Priority
        let animation: @Sendable () async -> Bool
        private var continuation: CheckedContinuation<Bool, Never>?

        init(id: UUID = UUID(), priority: Priority, animation: @Sendable @escaping () async -> Bool) {
            self.id = id
            self.priority = priority
            self.animation = animation
        }

        var completion: Bool {
            get async {
                await withCheckedContinuation { continuation in
                    self.continuation = continuation
                }
            }
        }

        func complete(with result: Bool) {
            self.continuation?.resume(returning: result)
        }
    }
}

// MARK: - Resource Pool

/// Manages reusable animation resources
@MainActor
final class AnimationResourcePool {
    /// Shared instance
    static let shared = AnimationResourcePool()

    /// Pool of reusable windows
    private var windowPool: [NSWindow] = []
    private let maxPoolSize = 10

    /// Logger
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "ResourcePool")

    private init() {}

    /// Get a window from the pool or create new
    func acquireWindow() -> NSWindow {
        if let window = windowPool.popLast() {
            self.logger.debug("Reusing window from pool")
            return window
        }

        self.logger.debug("Creating new window")
        return self.createWindow()
    }

    /// Return a window to the pool
    func releaseWindow(_ window: NSWindow) {
        // Reset window state
        window.orderOut(nil)
        window.contentView = nil
        window.alphaValue = 1.0

        if self.windowPool.count < self.maxPoolSize {
            self.windowPool.append(window)
            self.logger.debug("Returned window to pool (size: \(self.windowPool.count))")
        } else {
            // Pool is full, let it be deallocated
            self.logger.debug("Pool full, releasing window")
        }
    }

    /// Clean up pool
    func cleanup() {
        self.logger.info("Cleaning up resource pool")
        self.windowPool.removeAll()
    }

    private func createWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false

        return window
    }
}
