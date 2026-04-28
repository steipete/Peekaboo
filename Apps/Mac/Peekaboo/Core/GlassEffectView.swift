//
//  GlassEffectView.swift
//  Peekaboo
//

import AppKit
import SwiftUI

// MARK: - Glass Effects for macOS 26+

private let glassHostingViewIdentifier = NSUserInterfaceItemIdentifier("Peekaboo.GlassHostingView")

private func pinToEdges(_ child: NSView, of parent: NSView) {
    NSLayoutConstraint.activate([
        child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
        child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        child.topAnchor.constraint(equalTo: parent.topAnchor),
        child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
    ])
}

private func glassHostingView<Content: View>(
    in contentView: NSView?,
    fallbackView: NSView) -> NSHostingView<Content>?
{
    if let hostingView = contentView?.subviews
        .first(where: { $0.identifier == glassHostingViewIdentifier }) as? NSHostingView<Content>
    {
        return hostingView
    }

    return fallbackView.subviews
        .first(where: { $0.identifier == glassHostingViewIdentifier }) as? NSHostingView<Content>
}

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
        hostingView.identifier = glassHostingViewIdentifier
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = glassView.contentView {
            contentView.addSubview(hostingView)
            pinToEdges(hostingView, of: contentView)
        } else {
            glassView.addSubview(hostingView)
            pinToEdges(hostingView, of: glassView)
        }

        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        nsView.cornerRadius = self.cornerRadius
        nsView.tintColor = self.tintColor

        if let style {
            nsView.style = style
        }

        glassHostingView(in: nsView.contentView, fallbackView: nsView)?.rootView = self.content
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

    func makeNSView(context: Context) -> NSGlassEffectContainerView {
        let container = NSGlassEffectContainerView()
        container.spacing = self.spacing

        let hostingView = NSHostingView(rootView: content)
        hostingView.identifier = glassHostingViewIdentifier
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = container.contentView {
            contentView.addSubview(hostingView)
            pinToEdges(hostingView, of: contentView)
        } else {
            container.addSubview(hostingView)
            pinToEdges(hostingView, of: container)
        }

        return container
    }

    func updateNSView(_ nsView: NSGlassEffectContainerView, context: Context) {
        nsView.spacing = self.spacing

        glassHostingView(in: nsView.contentView, fallbackView: nsView)?.rootView = self.content
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
