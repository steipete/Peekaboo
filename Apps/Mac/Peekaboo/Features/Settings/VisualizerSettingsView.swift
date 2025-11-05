import os
import PeekabooCore
import PeekabooFoundation
import PeekabooUICore
import SwiftUI

struct VisualizerSettingsView: View {
    @Bindable var settings: PeekabooSettings
    @Environment(VisualizerCoordinator.self) private var visualizerCoordinator

    private let keyboardThemes = ["classic", "modern", "ghostly"]

    var body: some View {
        Form {
            // Header section with master toggle
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Visual Feedback")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Delightful animations for all Peekaboo operations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: self.$settings.visualizerEnabled)
                        .toggleStyle(IOSToggleStyle())
                }
            }

            // Animation Controls Section
            Section("Animation Settings") {
                // Animation Speed
                HStack {
                    Label("Animation Speed", systemImage: "speedometer")
                    Spacer()
                    Text(String(format: "%.1fx", self.settings.visualizerAnimationSpeed))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }

                Slider(value: self.$settings.visualizerAnimationSpeed, in: 0.1...2.0, step: 0.1)
                    .disabled(!self.settings.visualizerEnabled)

                // Effect Intensity
                HStack {
                    Label("Effect Intensity", systemImage: "wand.and.rays")
                    Spacer()
                    Text(String(format: "%.1fx", self.settings.visualizerEffectIntensity))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }

                Slider(value: self.$settings.visualizerEffectIntensity, in: 0.1...2.0, step: 0.1)
                    .disabled(!self.settings.visualizerEnabled)

                // Sound Effects
                HStack {
                    Label("Sound Effects", systemImage: "speaker.wave.2")
                    Spacer()
                    Toggle("", isOn: self.$settings.visualizerSoundEnabled)
                        .toggleStyle(IOSToggleStyle())
                }
                .disabled(!self.settings.visualizerEnabled)

                // Keyboard Theme
                VStack(alignment: .leading, spacing: 8) {
                    Label("Keyboard Theme", systemImage: "keyboard")
                    Picker("", selection: self.$settings.visualizerKeyboardTheme) {
                        ForEach(self.keyboardThemes, id: \.self) { theme in
                            Text(theme.capitalized).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!self.settings.visualizerEnabled)
                }
            }
            .opacity(self.settings.visualizerEnabled ? 1 : 0.5)

            // Individual Animations Section
            Section("Animation Types") {
                AnimationToggleRow(
                    title: "Screenshot Flash",
                    icon: "camera.viewfinder",
                    isOn: self.$settings.screenshotFlashEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "screenshot",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Click Animation",
                    icon: "cursorarrow.click",
                    isOn: self.$settings.clickAnimationEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "click",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Type Animation",
                    icon: "keyboard",
                    isOn: self.$settings.typeAnimationEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "type",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Scroll Animation",
                    icon: "arrow.up.arrow.down",
                    isOn: self.$settings.scrollAnimationEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "scroll",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Mouse Trail",
                    icon: "scribble",
                    isOn: self.$settings.mouseTrailEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "trail",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Swipe Path",
                    icon: "hand.draw",
                    isOn: self.$settings.swipePathEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "swipe",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Hotkey Overlay",
                    icon: "command",
                    isOn: self.$settings.hotkeyOverlayEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "hotkey",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "App Lifecycle",
                    icon: "app.badge",
                    isOn: self.$settings.appLifecycleEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "app_launch",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Window Operations",
                    icon: "macwindow",
                    isOn: self.$settings.windowOperationEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "window",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Menu Navigation",
                    icon: "menubar.rectangle",
                    isOn: self.$settings.menuNavigationEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "menu",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Dialog Interaction",
                    icon: "text.bubble",
                    isOn: self.$settings.dialogInteractionEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "dialog",
                    settings: self.settings)

                AnimationToggleRow(
                    title: "Space Transitions",
                    icon: "squares.below.rectangle",
                    isOn: self.$settings.spaceTransitionEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "space",
                    settings: self.settings)
            }
            .opacity(self.settings.visualizerEnabled ? 1 : 0.5)

            // Easter Eggs Section
            Section("Easter Eggs") {
                AnimationToggleRow(
                    title: "Ghost Animation",
                    subtitle: "Shows every 10th screenshot",
                    icon: "eye.slash",
                    isOn: self.$settings.ghostEasterEggEnabled,
                    isEnabled: self.settings.visualizerEnabled,
                    animationType: "ghost",
                    settings: self.settings)
            }
            .opacity(self.settings.visualizerEnabled ? 1 : 0.5)
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Supporting Views

struct AnimationToggleRow: View {
    let title: String
    var subtitle: String?
    let icon: String
    @Binding var isOn: Bool
    let isEnabled: Bool
    let animationType: String
    let settings: PeekabooSettings

    @Environment(VisualizerCoordinator.self) private var visualizerCoordinator
    @State private var isPreviewRunning = false

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.title)
                        .foregroundStyle(self.isEnabled ? .primary : .secondary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: self.icon)
                    .foregroundStyle(self.isEnabled ? Color.accentColor : .secondary)
            }

            Spacer()

            // Preview button
            Button {
                Task {
                    await self.runPreview()
                }
            } label: {
                Image(systemName: self.isPreviewRunning ? "stop.circle" : "play.circle")
                    .foregroundStyle(self.canPreview ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!self.canPreview || self.isPreviewRunning)
            .help("Preview \(self.title) animation")

            Toggle("", isOn: self.$isOn)
                .toggleStyle(IOSToggleStyle())
                .disabled(!self.isEnabled)
        }
    }

    private var canPreview: Bool {
        self.isEnabled && self.settings.visualizerEnabled && self.isOn
    }

    @MainActor
    private func runPreview() async {
        self.isPreviewRunning = true
        defer { self.isPreviewRunning = false }

        // Get screen for consistent positioning
        let screen = NSScreen.mouseScreen
        let centerPoint = CGPoint(x: screen.frame.midX, y: screen.frame.midY)

        // Run the appropriate preview animation
        switch self.animationType {
        case "screenshot":
            let rect = CGRect(
                x: screen.frame.midX - 200,
                y: screen.frame.midY - 150,
                width: 400,
                height: 300)
            _ = await self.visualizerCoordinator.showScreenshotFlash(in: rect)

        case "click":
            _ = await self.visualizerCoordinator.showClickFeedback(at: centerPoint, type: .single)

        case "type":
            let sampleKeys = ["H", "e", "l", "l", "o"]
            _ = await self.visualizerCoordinator.showTypingFeedback(keys: sampleKeys, duration: 2.0)

        case "scroll":
            _ = await self.visualizerCoordinator.showScrollFeedback(at: centerPoint, direction: .down, amount: 3)

        case "trail":
            let from = CGPoint(x: screen.frame.midX - 150, y: screen.frame.midY - 50)
            let to = CGPoint(x: screen.frame.midX + 150, y: screen.frame.midY + 50)
            _ = await self.visualizerCoordinator.showMouseMovement(from: from, to: to, duration: 1.5)

        case "swipe":
            let swipeFrom = CGPoint(x: screen.frame.midX - 100, y: screen.frame.midY)
            let swipeTo = CGPoint(x: screen.frame.midX + 100, y: screen.frame.midY)
            _ = await self.visualizerCoordinator.showSwipeGesture(from: swipeFrom, to: swipeTo, duration: 1.0)

        case "hotkey":
            let sampleKeys = ["⌘", "⇧", "P"]
            _ = await self.visualizerCoordinator.showHotkeyDisplay(keys: sampleKeys, duration: 2.0)

        case "app_launch":
            // Alternate between launch and quit for App Lifecycle
            if Bool.random() {
                _ = await self.visualizerCoordinator.showAppLaunch(appName: "Peekaboo", iconPath: nil as String?)
            } else {
                _ = await self.visualizerCoordinator.showAppQuit(appName: "TextEdit", iconPath: nil as String?)
            }

        case "window":
            let windowRect = CGRect(
                x: screen.frame.midX - 150,
                y: screen.frame.midY - 100,
                width: 300,
                height: 200)
            _ = await self.visualizerCoordinator.showWindowOperation(.move, windowRect: windowRect, duration: 1.0)

        case "menu":
            let menuPath = ["File", "Export", "PNG Image"]
            _ = await self.visualizerCoordinator.showMenuNavigation(menuPath: menuPath)

        case "dialog":
            let dialogRect = CGRect(
                x: screen.frame.midX - 100,
                y: screen.frame.midY - 25,
                width: 200,
                height: 50)
            _ = await self.visualizerCoordinator.showDialogInteraction(
                element: .button,
                elementRect: dialogRect,
                action: .clickButton)

        case "space":
            _ = await self.visualizerCoordinator.showSpaceSwitch(from: 1, to: 2, direction: .right)

        case "ghost":
            // For ghost easter egg, use the settings window itself for the flash
            if let window = NSApp.keyWindow {
                let windowFrame = window.frame
                _ = await self.visualizerCoordinator.showScreenshotFlash(in: windowFrame)
            } else {
                // Fallback to center screen if no key window
                let rect = CGRect(
                    x: screen.frame.midX - 200,
                    y: screen.frame.midY - 150,
                    width: 400,
                    height: 300)
                _ = await self.visualizerCoordinator.showScreenshotFlash(in: rect)
            }

        default:
            break
        }

        // Keep button in running state for a moment to show feedback
        try? await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - iOS-Style Toggle

struct IOSToggleStyle: ToggleStyle {
    typealias Body = IOSToggleView

    func makeBody(configuration: ToggleStyleConfiguration) -> Body {
        IOSToggleView(configuration: configuration)
    }
}

struct IOSToggleView: View {
    let configuration: ToggleStyleConfiguration

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(self.configuration.isOn ? Color.accentColor : Color(NSColor.tertiaryLabelColor))
            .frame(width: 36, height: 20)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .padding(2)
                    .offset(x: self.configuration.isOn ? 8 : -8)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: self.configuration.isOn))
            .onTapGesture {
                self.configuration.isOn.toggle()
            }
    }
}

#Preview {
    VisualizerSettingsView(settings: PeekabooSettings())
        .frame(width: 650, height: 1000)
}
