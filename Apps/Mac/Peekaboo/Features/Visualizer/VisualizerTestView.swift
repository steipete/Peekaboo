//
//  VisualizerTestView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import PeekabooCore
import PeekabooFoundation
import SwiftUI

/// Test view for all visualizer animations
struct VisualizerTestView: View {
    @State private var coordinator: VisualizerCoordinator
    @State private var selectedCategory = "Core"
    @State private var animationSpeed: Double = 1.0
    @State private var showPerformanceMetrics = false
    @State private var performanceReport: PerformanceReport?

    private let categories = ["Core", "Advanced", "System", "All"]
    private let performanceMonitor = PerformanceMonitor.shared

    init(coordinator: VisualizerCoordinator) {
        self._coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Text("Visualizer Test Suite")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Test all animation components")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Controls
            HStack(spacing: 20) {
                // Category picker
                Picker("Category", selection: self.$selectedCategory) {
                    ForEach(self.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)

                // Speed slider
                VStack(alignment: .leading) {
                    Text("Animation Speed: \(String(format: "%.1fx", self.animationSpeed))")
                        .font(.caption)
                    Slider(value: self.$animationSpeed, in: 0.1...3.0, step: 0.1)
                        .frame(width: 200)
                }

                // Performance toggle
                Toggle("Show Performance", isOn: self.$showPerformanceMetrics)
                    .onChange(of: self.showPerformanceMetrics) { _, newValue in
                        if newValue {
                            self.startPerformanceMonitoring()
                        } else {
                            self.stopPerformanceMonitoring()
                        }
                    }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Performance metrics
            if self.showPerformanceMetrics, let report = performanceReport {
                PerformanceMetricsView(report: report)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Animation buttons
            ScrollView {
                VStack(spacing: 15) {
                    if self.selectedCategory == "Core" || self.selectedCategory == "All" {
                        AnimationSection(title: "Core Animations") {
                            AnimationButton("Screenshot Flash") {
                                await self.testScreenshotFlash()
                            }

                            AnimationButton("Click Animation") {
                                await self.testClickAnimation()
                            }

                            AnimationButton("Type Animation") {
                                await self.testTypeAnimation()
                            }

                            AnimationButton("Scroll Animation") {
                                await self.testScrollAnimation()
                            }
                        }
                    }

                    if self.selectedCategory == "Advanced" || self.selectedCategory == "All" {
                        AnimationSection(title: "Advanced Animations") {
                            AnimationButton("Mouse Trail") {
                                await self.testMouseTrail()
                            }

                            AnimationButton("Swipe Gesture") {
                                await self.testSwipeGesture()
                            }

                            AnimationButton("Hotkey Display") {
                                await self.testHotkeyDisplay()
                            }

                            AnimationButton("App Launch") {
                                await self.testAppLaunch()
                            }

                            AnimationButton("App Quit") {
                                await self.testAppQuit()
                            }
                        }
                    }

                    if self.selectedCategory == "System" || self.selectedCategory == "All" {
                        AnimationSection(title: "System Animations") {
                            AnimationButton("Window Close") {
                                await self.testWindowOperation(.close)
                            }

                            AnimationButton("Window Minimize") {
                                await self.testWindowOperation(.minimize)
                            }

                            AnimationButton("Window Maximize") {
                                await self.testWindowOperation(.maximize)
                            }

                            AnimationButton("Menu Navigation") {
                                await self.testMenuNavigation()
                            }

                            AnimationButton("Dialog Interaction") {
                                await self.testDialogInteraction()
                            }

                            AnimationButton("Space Switch") {
                                await self.testSpaceSwitch()
                            }
                        }
                    }

                    // Stress test
                    AnimationSection(title: "Stress Tests") {
                        AnimationButton("Concurrent Animations (5)", systemImage: "flame") {
                            await self.testConcurrentAnimations(count: 5)
                        }

                        AnimationButton("Rapid Fire (10)", systemImage: "bolt") {
                            await self.testRapidFire(count: 10)
                        }

                        AnimationButton("Memory Test (50)", systemImage: "memorychip") {
                            await self.testMemoryUsage(count: 50)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 800, height: 600)
        .padding()
        .onAppear {
            // Settings are managed through PeekabooSettings now
            // Animation speed can be adjusted through the test UI
        }
    }

    // MARK: - Test Methods

    func testScreenshotFlash() async {
        let rect = CGRect(x: 100, y: 100, width: 600, height: 400)
        _ = await self.coordinator.showScreenshotFlash(in: rect)
    }

    func testClickAnimation() async {
        let point = CGPoint(x: 400, y: 300)
        _ = await self.coordinator.showClickFeedback(at: point, type: .single)
    }

    func testTypeAnimation() async {
        let keys = ["H", "e", "l", "l", "o", "Space", "W", "o", "r", "l", "d"]
        _ = await self.coordinator.showTypingFeedback(
            keys: keys,
            duration: 3.0,
            cadence: .human(wordsPerMinute: 55))
    }

    func testScrollAnimation() async {
        let point = CGPoint(x: 400, y: 300)
        _ = await self.coordinator.showScrollFeedback(at: point, direction: .down, amount: 5)
    }

    func testMouseTrail() async {
        let from = CGPoint(x: 200, y: 200)
        let to = CGPoint(x: 600, y: 400)
        _ = await self.coordinator.showMouseMovement(from: from, to: to, duration: 1.0)
    }

    func testSwipeGesture() async {
        let from = CGPoint(x: 200, y: 300)
        let to = CGPoint(x: 600, y: 300)
        _ = await self.coordinator.showSwipeGesture(from: from, to: to, duration: 0.5)
    }

    func testHotkeyDisplay() async {
        let keys = ["Cmd", "Shift", "T"]
        _ = await self.coordinator.showHotkeyDisplay(keys: keys, duration: 2.0)
    }

    func testAppLaunch() async {
        _ = await self.coordinator.showAppLaunch(appName: "TestApp", iconPath: nil as String?)
    }

    func testAppQuit() async {
        _ = await self.coordinator.showAppQuit(appName: "TestApp", iconPath: nil as String?)
    }

    private func testWindowOperation(_ operation: WindowOperation) async {
        let rect = CGRect(x: 200, y: 150, width: 400, height: 300)
        _ = await self.coordinator.showWindowOperation(operation, windowRect: rect, duration: 0.5)
    }

    func testMenuNavigation() async {
        let menuPath = ["File", "New", "Project"]
        _ = await self.coordinator.showMenuNavigation(menuPath: menuPath)
    }

    func testDialogInteraction() async {
        let rect = CGRect(x: 350, y: 250, width: 120, height: 40)
        _ = await self.coordinator.showDialogInteraction(
            element: .button,
            elementRect: rect,
            action: .clickButton)
    }

    func testSpaceSwitch() async {
        _ = await self.coordinator.showSpaceSwitch(from: 1, to: 2, direction: SpaceDirection.right)
    }

    private func testConcurrentAnimations(count: Int) async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    let point = CGPoint(
                        x: 200 + Double(i * 100),
                        y: 200 + Double(i * 50))
                    _ = await self.coordinator.showClickFeedback(at: point, type: .single)
                }
            }
        }
    }

    private func testRapidFire(count: Int) async {
        for _ in 0..<count {
            let point = CGPoint(x: 400, y: 300)
            _ = await self.coordinator.showClickFeedback(at: point, type: .single)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }

    private func testMemoryUsage(count: Int) async {
        for i in 0..<count {
            let rect = CGRect(
                x: Double.random(in: 100...700),
                y: Double.random(in: 100...500),
                width: 100,
                height: 100)
            _ = await self.coordinator.showScreenshotFlash(in: rect)

            if i % 10 == 0 {
                // Give time for cleanup
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }

    // MARK: - Performance Monitoring

    private func startPerformanceMonitoring() {
        self.performanceMonitor.startMonitoring()

        // Update metrics periodically
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                self.performanceReport = await self.performanceMonitor.getPerformanceReport()
            }
        }
    }

    private func stopPerformanceMonitoring() {
        self.performanceMonitor.stopMonitoring()
        Task {
            await self.performanceMonitor.logPerformanceReport()
        }
    }
}

// MARK: - Supporting Views

struct AnimationSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(self.title)
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                self.content
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct AnimationButton: View {
    let title: String
    let systemImage: String?
    let action: () async -> Void

    @State private var isRunning = false

    init(_ title: String, systemImage: String? = nil, action: @escaping () async -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: {
            Task {
                self.isRunning = true
                await self.action()
                self.isRunning = false
            }
        }, label: {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(self.title)

                Spacer()

                if self.isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        })
        .buttonStyle(PlainButtonStyle())
        .background(self.isRunning ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
        .disabled(self.isRunning)
    }
}

struct PerformanceMetricsView: View {
    let report: PerformanceReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)

            HStack(spacing: 20) {
                MetricView(label: "FPS", value: String(format: "%.1f", self.report.currentFPS))
                MetricView(label: "Memory", value: String(format: "%.1f MB", self.report.memoryUsageMB))
                MetricView(label: "Active", value: "\(self.report.activeAnimations)")
                MetricView(label: "Total", value: "\(self.report.totalAnimations)")
                MetricView(label: "Peak", value: "\(self.report.peakConcurrentAnimations)")
            }

            if !self.report.slowestAnimations.isEmpty {
                Text("Slowest Animations:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(self.report.slowestAnimations, id: \.type) { animation in
                    HStack {
                        Text(animation.type)
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.3fs", animation.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(animation.duration > 1.0 ? .red : .secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .animation(.easeInOut, value: self.report.activeAnimations)
    }
}

struct MetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(self.value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

#Preview {
    VisualizerTestView(coordinator: VisualizerCoordinator())
}
