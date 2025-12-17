import AppKit
import SwiftUI

struct MouseMoveProbeView: NSViewRepresentable {
    @EnvironmentObject var actionLogger: ActionLogger

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.actionLogger = self.actionLogger
        return view
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.actionLogger = self.actionLogger
    }

    final class ProbeView: NSView {
        weak var actionLogger: ActionLogger?
        private var lastLoggedAt: CFAbsoluteTime = 0
        private var trackingArea: NSTrackingArea?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.configureAccessibility()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.configureAccessibility()
        }

        private func configureAccessibility() {
            self.setAccessibilityElement(true)
            self.setAccessibilityRole(.group)
            self.setAccessibilityIdentifier("mouse-move-probe")
            self.setAccessibilityLabel("Mouse Move Probe")
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingArea {
                self.removeTrackingArea(trackingArea)
            }

            let options: NSTrackingArea.Options = [
                .activeInKeyWindow,
                .inVisibleRect,
                .mouseEnteredAndExited,
                .mouseMoved,
            ]
            let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            self.addTrackingArea(trackingArea)
            self.trackingArea = trackingArea
        }

        override func mouseEntered(with event: NSEvent) {
            self.actionLogger?.log(.control, "Mouse entered probe area")
        }

        override func mouseExited(with event: NSEvent) {
            self.actionLogger?.log(.control, "Mouse exited probe area")
        }

        override func mouseMoved(with event: NSEvent) {
            let now = CFAbsoluteTimeGetCurrent()
            // Rate-limit to keep OSLog readable while still proving movement happened.
            guard now - self.lastLoggedAt > 0.25 else { return }
            self.lastLoggedAt = now

            let inWindow = event.locationInWindow
            let inView = self.convert(inWindow, from: nil)
            let detail = "local=(\(Int(inView.x)), \(Int(inView.y)))"
            self.actionLogger?.log(.control, "Mouse moved over probe area", details: detail)
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.systemYellow.withAlphaComponent(0.08).setFill()
            dirtyRect.fill()

            NSColor.systemYellow.withAlphaComponent(0.35).setStroke()
            let path = NSBezierPath(roundedRect: self.bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
            path.lineWidth = 2
            path.stroke()
        }
    }
}
