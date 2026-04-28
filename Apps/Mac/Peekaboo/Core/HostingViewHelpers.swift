//
//  HostingViewHelpers.swift
//  Peekaboo
//

import AppKit
import SwiftUI

func makeHostedContentView<Content: View>(
    _ content: Content,
    identifier: NSUserInterfaceItemIdentifier) -> NSHostingView<Content>
{
    let hostingView = NSHostingView(rootView: content)
    hostingView.identifier = identifier
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    return hostingView
}

func pinHostedContentView(_ child: NSView, to parent: NSView) {
    NSLayoutConstraint.activate([
        child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
        child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        child.topAnchor.constraint(equalTo: parent.topAnchor),
        child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
    ])
}

func hostedContentView<Content: View>(
    identifiedBy identifier: NSUserInterfaceItemIdentifier,
    in contentView: NSView?,
    fallbackView: NSView) -> NSHostingView<Content>?
{
    if let hostingView = contentView?.subviews
        .first(where: { $0.identifier == identifier }) as? NSHostingView<Content>
    {
        return hostingView
    }

    return fallbackView.subviews
        .first(where: { $0.identifier == identifier }) as? NSHostingView<Content>
}
