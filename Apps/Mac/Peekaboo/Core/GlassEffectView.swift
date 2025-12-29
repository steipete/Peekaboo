//
//  GlassEffectView.swift
//  Peekaboo
//

import AppKit
import SwiftUI

// MARK: - Glass Effects for macOS 26+

/// Liquid Glass effects are only available on macOS 26+
/// For older versions, use ModernEffects.swift which provides platform-native styling
@available(macOS 26.0, *)
struct GlassEffectView<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let tintColor: NSColor?
    let style: NSGlassEffectView.Style?
    let content: Content

    init(
        cornerRadius: CGFloat = 10,
        tintColor: NSColor? = nil,
        style: NSGlassEffectView.Style? = nil,
        @ViewBuilder content: () -> Content)
    {
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.style = style
        self.content = content()
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        glassView.cornerRadius = self.cornerRadius

        if let tintColor {
            glassView.tintColor = tintColor
        }

        if let style {
            glassView.style = style
        }

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
        nsView.tintColor = self.tintColor

        if let style {
            nsView.style = style
        }

        context.coordinator.hostingView?.rootView = self.content
    }
}

// MARK: - Glass Container for macOS 26+

@available(macOS 26.0, *)
struct GlassEffectContainer<Content: View>: NSViewRepresentable {
    let spacing: CGFloat
    let content: Content

    init(
        spacing: CGFloat = 20,
        @ViewBuilder content: () -> Content)
    {
        self.spacing = spacing
        self.content = content()
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSGlassEffectContainerView {
        let container = NSGlassEffectContainerView()
        container.spacing = self.spacing

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.hostingView = hostingView

        if let contentView = container.contentView {
            contentView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        } else {
            container.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: container.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        return container
    }

    func updateNSView(_ nsView: NSGlassEffectContainerView, context: Context) {
        nsView.spacing = self.spacing

        context.coordinator.hostingView?.rootView = self.content
    }
}

// MARK: - Glass Extensions for macOS 26+

@available(macOS 26.0, *)
extension View {
    /// Applies Liquid Glass background (macOS 26+ only)
    func glassBackground(
        cornerRadius: CGFloat = 10,
        tintColor: NSColor? = nil,
        style: NSGlassEffectView.Style? = nil) -> some View
    {
        background {
            GlassEffectView(
                cornerRadius: cornerRadius,
                tintColor: tintColor,
                style: style)
            {
                Color.clear
            }
        }
    }

    /// Wraps content in Liquid Glass (macOS 26+ only)
    func glassEffect(
        cornerRadius: CGFloat = 10,
        tintColor: NSColor? = nil,
        style: NSGlassEffectView.Style? = nil) -> some View
    {
        GlassEffectView(
            cornerRadius: cornerRadius,
            tintColor: tintColor,
            style: style)
        {
            self
        }
    }
}
