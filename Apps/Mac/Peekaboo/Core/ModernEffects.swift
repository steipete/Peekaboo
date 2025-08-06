//
//  ModernEffects.swift
//  Peekaboo
//

import SwiftUI
import AppKit

// MARK: - Modern Visual Effects with Platform-Appropriate Styling

/// Provides modern visual effects that look native on each macOS version
/// - macOS 14-25: Uses native materials and standard macOS styling
/// - macOS 26+: Uses new Liquid Glass effects when available
@available(macOS 14.0, *)
struct ModernEffectView<Content: View>: View {
    let style: ModernEffectStyle
    let cornerRadius: CGFloat
    let content: Content
    
    init(style: ModernEffectStyle = .automatic,
         cornerRadius: CGFloat = 10,  // macOS standard corner radius
         @ViewBuilder content: () -> Content) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            // Use new Liquid Glass on macOS 26+
            NativeGlassWrapper(
                style: style,
                cornerRadius: cornerRadius,
                content: content
            )
        } else {
            // Use standard macOS materials for 14-25
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(style.nativeMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
            return .regular
        case .sidebar:
            return .bar  // Sidebar-appropriate material
        case .content:
            return .regularMaterial
        case .popover:
            return .ultraThinMaterial  // Light material for popovers
        case .hudWindow:
            return .ultraThickMaterial  // Heavy material for HUD
        case .toolbar:
            return .bar  // Toolbar-appropriate material
        case .selection:
            return .thick  // Selection highlighting
        }
    }
    
    /// Returns the glass style for macOS 26+
    @available(macOS 26.0, *)
    var glassStyle: NSGlassEffectView.Style {
        // This will map to appropriate glass styles when available
        // For now, using placeholder since the enum isn't defined yet
        return NSGlassEffectView.Style(rawValue: 0)!
    }
}

// MARK: - Native Glass Wrapper for macOS 26+

@available(macOS 26.0, *)
struct NativeGlassWrapper<Content: View>: NSViewRepresentable {
    let style: ModernEffectStyle
    let cornerRadius: CGFloat
    let content: Content
    
    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.cornerRadius = cornerRadius
        glassView.style = style.glassStyle
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        glassView.contentView = hostingView
        
        if let contentView = glassView.contentView {
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        
        return glassView
    }
    
    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.style = style.glassStyle
        
        if let hostingView = nsView.contentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

// MARK: - Modern Button (Native on Each Platform)

struct ModernButton: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void
    
    init(_ title: String,
         systemImage: String? = nil,
         role: ButtonRole? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            // Use glass button style on macOS 26+
            Button(role: role, action: action) {
                Label(title, systemImage: systemImage ?? "")
            }
            .buttonStyle(.glass)
        } else {
            // Use standard macOS button styles
            Button(role: role, action: action) {
                if let systemImage = systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .buttonStyle(.automatic)  // Let macOS decide the appropriate style
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
            content
                .padding()
                .background {
                    ModernEffectView(style: .content) {
                        Color.clear
                    }
                }
        } else {
            // Standard macOS card styling
            content
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
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
                content
            }
        } else {
            // Standard macOS toolbar material
            content
                .background(.bar)
        }
    }
}

// MARK: - View Extensions for Easy Adoption

extension View {
    /// Applies platform-appropriate modern background
    func modernBackground(style: ModernEffectStyle = .automatic,
                         cornerRadius: CGFloat = 10) -> some View {
        background {
            ModernEffectView(style: style, cornerRadius: cornerRadius) {
                Color.clear
            }
        }
    }
    
    /// Wraps content in platform-appropriate modern effect
    func modernEffect(style: ModernEffectStyle = .automatic,
                     cornerRadius: CGFloat = 10) -> some View {
        ModernEffectView(style: style, cornerRadius: cornerRadius) {
            self
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