//
//  VisualizerConfiguration.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import Foundation
import SwiftUI

/// Configuration for the visualizer system
struct VisualizerConfiguration: Codable {
    // MARK: - Global Settings

    /// Whether the visualizer is enabled
    var isEnabled: Bool = true

    /// Global animation speed multiplier (0.1 - 3.0)
    var animationSpeed: Double = 1.0

    /// Global effect intensity (0.0 - 1.0)
    var effectIntensity: Double = 1.0

    /// Whether to respect reduced motion settings
    var respectReducedMotion: Bool = true

    // MARK: - Performance Settings

    /// Maximum concurrent animations
    var maxConcurrentAnimations: Int = 5

    /// Animation queue batch interval (seconds)
    var batchInterval: TimeInterval = 0.016 // ~60 FPS

    /// Enable performance monitoring
    var enablePerformanceMonitoring: Bool = false

    /// Window pool size
    var windowPoolSize: Int = 10

    // MARK: - Animation Feature Flags

    /// Screenshot flash animation
    var screenshotFlashEnabled: Bool = true
    var screenshotFlashDuration: TimeInterval = 0.2
    var screenshotGhostEasterEgg: Bool = true

    /// Click animations
    var clickAnimationEnabled: Bool = true
    var clickAnimationDuration: TimeInterval = 0.5
    var clickRippleCount: Int = 3

    /// Typing feedback
    var typingFeedbackEnabled: Bool = true
    var typingWidgetPosition: WidgetPosition = .bottomCenter
    var typingAnimationDelay: TimeInterval = 0.05

    /// Scroll indicators
    var scrollIndicatorEnabled: Bool = true
    var scrollIndicatorSize: CGFloat = 100
    var scrollArrowCount: Int = 3

    /// Mouse trail
    var mouseTrailEnabled: Bool = true
    var mouseTrailParticleCount: Int = 5
    var mouseTrailFadeDelay: TimeInterval = 0.3

    /// Swipe gestures
    var swipeGestureEnabled: Bool = true
    var swipePathSteps: Int = 10
    var swipeParticleCount: Int = 8

    /// Hotkey display
    var hotkeyDisplayEnabled: Bool = true
    var hotkeyDisplayDuration: TimeInterval = 1.5
    var hotkeyParticleCount: Int = 12

    /// App lifecycle
    var appAnimationsEnabled: Bool = true
    var appLaunchDuration: TimeInterval = 2.0
    var appQuitDuration: TimeInterval = 1.5

    /// Window operations
    var windowAnimationsEnabled: Bool = true
    var windowOperationDuration: TimeInterval = 0.5

    /// Menu navigation
    var menuHighlightEnabled: Bool = true
    var menuItemDelay: TimeInterval = 0.2

    /// Dialog interactions
    var dialogFeedbackEnabled: Bool = true
    var dialogHighlightDuration: TimeInterval = 1.0

    /// Space transitions
    var spaceAnimationEnabled: Bool = true
    var spaceTransitionDuration: TimeInterval = 1.0

    /// Element detection
    var elementOverlaysEnabled: Bool = true
    var elementHighlightColor: String = "#FF9500" // Orange

    // MARK: - Visual Settings

    /// Default colors
    var primaryColor: String = "#007AFF" // Blue
    var secondaryColor: String = "#5AC8FA" // Light Blue
    var successColor: String = "#34C759" // Green
    var warningColor: String = "#FF9500" // Orange
    var errorColor: String = "#FF3B30" // Red

    /// Shadow settings
    var enableShadows: Bool = true
    var shadowRadius: CGFloat = 10
    var shadowOpacity: Double = 0.5

    /// Blur settings
    var enableBlur: Bool = true
    var blurRadius: CGFloat = 20

    // MARK: - Methods

    /// Load configuration from disk
    static func load() -> VisualizerConfiguration {
        let configURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Peekaboo")
            .appendingPathComponent("visualizer-config.json")

        guard let url = configURL,
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(VisualizerConfiguration.self, from: data)
        else {
            return VisualizerConfiguration()
        }

        return config
    }

    /// Save configuration to disk
    func save() {
        let configURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Peekaboo")

        guard let url = configURL else { return }

        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let fileURL = url.appendingPathComponent("visualizer-config.json")

        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: fileURL)
        }
    }

    /// Apply reduced motion settings
    mutating func applyReducedMotion() {
        if self.respectReducedMotion, NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            // Reduce animation speeds
            self.animationSpeed = 0.5

            // Disable particle effects
            self.clickRippleCount = 1
            self.scrollArrowCount = 1
            self.mouseTrailParticleCount = 2
            self.swipeParticleCount = 4
            self.hotkeyParticleCount = 6

            // Disable complex animations
            self.mouseTrailEnabled = false
            self.spaceAnimationEnabled = false

            // Reduce visual effects
            self.enableShadows = false
            self.enableBlur = false
        }
    }

    // MARK: - Nested Types

    enum WidgetPosition: String, Codable {
        case topLeft, topCenter, topRight
        case middleLeft, center, middleRight
        case bottomLeft, bottomCenter, bottomRight

        var alignment: Alignment {
            switch self {
            case .topLeft: .topLeading
            case .topCenter: .top
            case .topRight: .topTrailing
            case .middleLeft: .leading
            case .center: .center
            case .middleRight: .trailing
            case .bottomLeft: .bottomLeading
            case .bottomCenter: .bottom
            case .bottomRight: .bottomTrailing
            }
        }

        func offset(in frame: CGRect, widgetSize: CGSize) -> CGPoint {
            switch self {
            case .topLeft:
                CGPoint(x: 50, y: frame.maxY - widgetSize.height - 50)
            case .topCenter:
                CGPoint(x: frame.midX - widgetSize.width / 2, y: frame.maxY - widgetSize.height - 50)
            case .topRight:
                CGPoint(x: frame.maxX - widgetSize.width - 50, y: frame.maxY - widgetSize.height - 50)
            case .middleLeft:
                CGPoint(x: 50, y: frame.midY - widgetSize.height / 2)
            case .center:
                CGPoint(x: frame.midX - widgetSize.width / 2, y: frame.midY - widgetSize.height / 2)
            case .middleRight:
                CGPoint(x: frame.maxX - widgetSize.width - 50, y: frame.midY - widgetSize.height / 2)
            case .bottomLeft:
                CGPoint(x: 50, y: 50)
            case .bottomCenter:
                CGPoint(x: frame.midX - widgetSize.width / 2, y: 50)
            case .bottomRight:
                CGPoint(x: frame.maxX - widgetSize.width - 50, y: 50)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255)
    }
}
