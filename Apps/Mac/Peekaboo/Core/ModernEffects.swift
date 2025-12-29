//
//  ModernEffects.swift
//  Peekaboo
//

import AppKit
import SwiftUI

// MARK: - Modern Visual Effects with Platform-Appropriate Styling

/// Provides modern visual effects that look native on each macOS version
/// - macOS 14-25: Uses native materials and standard macOS styling
/// - macOS 26+: Uses new Liquid Glass effects when available
@available(macOS 14.0, *)
struct ModernEffectView<Content: View>: View {
    let style: ModernEffectStyle
    let cornerRadius: CGFloat
    let content: Content

    init(
        style: ModernEffectStyle = .automatic,
        cornerRadius: CGFloat = 10, // macOS standard corner radius
        @ViewBuilder content: () -> Content)
    {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            // Use new Liquid Glass on macOS 26+
            NativeGlassWrapper(
                style: self.style,
                cornerRadius: self.cornerRadius,
                content: self.content)
        } else {
            // Use standard macOS materials for 14-25
            self.content
                .background {
                    RoundedRectangle(cornerRadius: self.cornerRadius)
                        .fill(self.style.nativeMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: self.cornerRadius))
        }
    }
}

// MARK: - Effect Styles

enum ModernEffectStyle {
    case automatic
    case sidebar
    case content
    case popover
    case hudWindow
    case toolbar
    case selection

    /// Returns the appropriate native material for macOS 14-25
    var nativeMaterial: Material {
        switch self {
        case .automatic:
            .regular
        case .sidebar:
            .bar // Sidebar-appropriate material
        case .content:
            .regularMaterial
        case .popover:
            .ultraThinMaterial // Light material for popovers
        case .hudWindow:
            .ultraThickMaterial // Heavy material for HUD
        case .toolbar:
            .bar // Toolbar-appropriate material
        case .selection:
            .thick // Selection highlighting
        }
    }

    /// Returns the glass style for macOS 26+
    @available(macOS 26.0, *)
    var glassStyle: NSGlassEffectView.Style {
        // This will map to appropriate glass styles when available
        // For now, using placeholder since the enum isn't defined yet
        NSGlassEffectView.Style(rawValue: 0)!
    }
}

// MARK: - Native Glass Wrapper for macOS 26+

@available(macOS 26.0, *)
struct NativeGlassWrapper<Content: View>: NSViewRepresentable {
    let style: ModernEffectStyle
    let cornerRadius: CGFloat
    let content: Content

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.cornerRadius = self.cornerRadius
        glassView.style = self.style.glassStyle

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.hostingView = hostingView

        if let contentView = glassView.contentView {
            contentView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        } else {
            glassView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: glassView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor),
            ])
        }

        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = self.cornerRadius
        nsView.style = self.style.glassStyle
        context.coordinator.hostingView?.rootView = self.content
    }
}

// MARK: - Modern Button (Native on Each Platform)

struct ModernButton: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () -> Void)
    {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            // Use glass button style on macOS 26+
            Button(role: self.role, action: self.action) {
                Label(self.title, systemImage: self.systemImage ?? "")
            }
            .buttonStyle(.glass)
        } else {
            // Use standard macOS button styles
            Button(role: self.role, action: self.action) {
                if let systemImage {
                    Label(self.title, systemImage: systemImage)
                } else {
                    Text(self.title)
                }
            }
            .buttonStyle(.automatic) // Let macOS decide the appropriate style
        }
    }
}

// MARK: - Modern Card (Platform-Appropriate)

struct ModernCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            // Glass card on macOS 26+
            self.content
                .padding()
                .background {
                    ModernEffectView(style: .content) {
                        Color.clear
                    }
                }
        } else {
            // Standard macOS card styling
            self.content
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        }
    }
}

// MARK: - Modern Toolbar

struct ModernToolbar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            // Glass toolbar on macOS 26+
            ModernEffectView(style: .toolbar) {
                self.content
            }
        } else {
            // Standard macOS toolbar material
            self.content
                .background(.bar)
        }
    }
}

// MARK: - View Extensions for Easy Adoption

extension View {
    /// Applies platform-appropriate modern background
    func modernBackground(
        style: ModernEffectStyle = .automatic,
        cornerRadius: CGFloat = 10) -> some View
    {
        background {
            ModernEffectView(style: style, cornerRadius: cornerRadius) {
                Color.clear
            }
        }
    }

    /// Wraps content in platform-appropriate modern effect
    func modernEffect(
        style: ModernEffectStyle = .automatic,
        cornerRadius: CGFloat = 10) -> some View
    {
        ModernEffectView(style: style, cornerRadius: cornerRadius) {
            self
        }
    }

    /// Renders a glass-style surface that automatically falls back to native materials
    /// on platforms that do not support Liquid Glass yet.
    func glassSurface(
        style: ModernEffectStyle = .content,
        cornerRadius: CGFloat = 16) -> some View
    {
        modifier(GlassSurfaceModifier(style: style, cornerRadius: cornerRadius))
    }
}

// MARK: - Shared Glass Surface Modifier

private struct GlassSurfaceModifier: ViewModifier {
    let style: ModernEffectStyle
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassBackground(
                    cornerRadius: self.cornerRadius,
                    tintColor: NSColor(calibratedWhite: 0.08, alpha: 0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.12),
                            lineWidth: 0.5)
                        .blendMode(.plusLighter)
                }
        } else {
            content
                .modernBackground(style: self.style, cornerRadius: self.cornerRadius)
                .overlay {
                    RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        .blendMode(.plusLighter)
                }
        }
    }
}

// MARK: - Modern Button Style

struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            // Will use glass button style when available
            configuration.label
                .buttonStyle(.glass)
        } else {
            // Use standard bordered style for current macOS
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == ModernButtonStyle {
    /// Modern button style that adapts to platform
    static var modern: ModernButtonStyle {
        ModernButtonStyle()
    }
}
