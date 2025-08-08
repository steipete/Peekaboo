//
//  PerformanceMonitor.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import Foundation
import os
import QuartzCore

/// Monitors performance metrics for the visualizer system
@MainActor
final class PerformanceMonitor {
    // MARK: - Properties

    /// Shared instance
    static let shared = PerformanceMonitor()

    /// Logger for performance metrics
    private let logger = Logger(subsystem: "boo.peekaboo.mac", category: "PerformanceMonitor")

    /// Performance metrics storage
    private var metrics = Metrics()

    /// Frame rate monitor
    private var frameTimer: Timer?

    /// Last frame timestamp
    private var lastFrameTime: CFTimeInterval = 0

    /// Frame times for FPS calculation
    private var frameTimes: [CFTimeInterval] = []
    private let maxFrameSamples = 60

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start monitoring performance
    func startMonitoring() {
        // Use Timer on macOS instead of CADisplayLink
        self.frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.frameTimerCallback()
            }
        }

        self.logger.info("Performance monitoring started")
    }

    /// Stop monitoring performance
    func stopMonitoring() {
        self.frameTimer?.invalidate()
        self.frameTimer = nil

        self.logger.info("Performance monitoring stopped")
    }

    /// Record animation start
    func recordAnimationStart(type: String) -> AnimationTracker {
        let tracker = AnimationTracker(type: type)
        self.metrics.activeAnimations += 1
        self.metrics.totalAnimations += 1

        if self.metrics.activeAnimations > self.metrics.peakConcurrentAnimations {
            self.metrics.peakConcurrentAnimations = self.metrics.activeAnimations
        }

        return tracker
    }

    /// Record animation completion
    func recordAnimationComplete(tracker: AnimationTracker) {
        let duration = tracker.complete()
        self.metrics.activeAnimations = max(0, self.metrics.activeAnimations - 1)

        // Update animation metrics
        self.metrics.animationDurations.append((tracker.type, duration))
        if self.metrics.animationDurations.count > 100 {
            self.metrics.animationDurations.removeFirst()
        }

        // Check for performance issues
        if duration > 1.0 {
            self.logger.warning("Slow animation detected: \(tracker.type) took \(String(format: "%.2f", duration))s")
        }
    }

    /// Get current FPS
    func getCurrentFPS() -> Double {
        guard !self.frameTimes.isEmpty else { return 0 }

        let averageFrameTime = self.frameTimes.reduce(0, +) / Double(self.frameTimes.count)
        return averageFrameTime > 0 ? 1.0 / averageFrameTime : 0
    }

    /// Get memory usage
    func getMemoryUsage() -> (used: Double, total: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: 1) { pointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    pointer,
                    &count)
            }
        }

        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            return (usedMB, totalMB)
        }

        return (0, 0)
    }

    /// Get performance report
    func getPerformanceReport() async -> PerformanceReport {
        let (usedMemory, totalMemory) = self.getMemoryUsage()

        // Calculate average animation duration
        let averageDuration: TimeInterval
        if !self.metrics.animationDurations.isEmpty {
            let totalDuration = self.metrics.animationDurations.reduce(0) { $0 + $1.1 }
            averageDuration = totalDuration / Double(self.metrics.animationDurations.count)
        } else {
            averageDuration = 0
        }

        // Find slowest animations
        let slowestAnimations = self.metrics.animationDurations
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { (type: $0.0, duration: $0.1) }

        return PerformanceReport(
            currentFPS: self.getCurrentFPS(),
            averageFPS: self.calculateAverageFPS(),
            memoryUsageMB: usedMemory,
            totalMemoryMB: totalMemory,
            activeAnimations: self.metrics.activeAnimations,
            totalAnimations: self.metrics.totalAnimations,
            peakConcurrentAnimations: self.metrics.peakConcurrentAnimations,
            averageAnimationDuration: averageDuration,
            slowestAnimations: slowestAnimations)
    }

    /// Log performance report
    func logPerformanceReport() async {
        let report = await self.getPerformanceReport()

        self.logger.info("""
        Performance Report:
        - FPS: \(String(format: "%.1f", report.currentFPS)) (avg: \(String(format: "%.1f", report.averageFPS)))
        - Memory: \(String(format: "%.1f", report.memoryUsageMB))MB / \(String(format: "%.1f", report.totalMemoryMB))MB
        - Active Animations: \(report.activeAnimations)
        - Total Animations: \(report.totalAnimations)
        - Peak Concurrent: \(report.peakConcurrentAnimations)
        - Avg Duration: \(String(format: "%.3f", report.averageAnimationDuration))s
        """)

        if !report.slowestAnimations.isEmpty {
            self.logger.info("Slowest animations:")
            for (type, duration) in report.slowestAnimations {
                self.logger.info("  - \(type): \(String(format: "%.3f", duration))s")
            }
        }
    }

    // MARK: - Private Methods

    private func frameTimerCallback() {
        let currentTime = CACurrentMediaTime()

        if self.lastFrameTime > 0 {
            let frameTime = currentTime - self.lastFrameTime
            self.frameTimes.append(frameTime)

            if self.frameTimes.count > self.maxFrameSamples {
                self.frameTimes.removeFirst()
            }

            // Check for frame drops
            if frameTime > 0.02 { // More than 20ms (50 FPS threshold)
                self.metrics.droppedFrames += 1
            }
        }

        self.lastFrameTime = currentTime
    }

    private func calculateAverageFPS() -> Double {
        guard !self.frameTimes.isEmpty else { return 0 }

        let totalTime = self.frameTimes.reduce(0, +)
        let averageFrameTime = totalTime / Double(self.frameTimes.count)

        return averageFrameTime > 0 ? 1.0 / averageFrameTime : 0
    }

    // MARK: - Nested Types

    /// Performance metrics storage
    private struct Metrics {
        var activeAnimations = 0
        var totalAnimations = 0
        var peakConcurrentAnimations = 0
        var droppedFrames = 0
        var animationDurations: [(type: String, duration: TimeInterval)] = []
    }
}

// MARK: - AnimationTracker

/// Tracks individual animation performance
final class AnimationTracker: @unchecked Sendable {
    let type: String
    let startTime: CFTimeInterval
    private(set) var endTime: CFTimeInterval?

    init(type: String) {
        self.type = type
        self.startTime = CACurrentMediaTime()
    }

    func complete() -> TimeInterval {
        self.endTime = CACurrentMediaTime()
        return (self.endTime ?? self.startTime) - self.startTime
    }
}

// MARK: - PerformanceReport

/// Performance report data
struct PerformanceReport {
    let currentFPS: Double
    let averageFPS: Double
    let memoryUsageMB: Double
    let totalMemoryMB: Double
    let activeAnimations: Int
    let totalAnimations: Int
    let peakConcurrentAnimations: Int
    let averageAnimationDuration: TimeInterval
    let slowestAnimations: [(type: String, duration: TimeInterval)]
}
