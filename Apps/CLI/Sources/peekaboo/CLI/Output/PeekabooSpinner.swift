//
//  PeekabooSpinner.swift
//  PeekabooCore
//

import Foundation
import Spinner

/// Modern spinner implementation using the Spinner library
@available(macOS 14.0, *)
@MainActor
final class PeekabooSpinner {
    private var spinner: Spinner?
    private let supportsColors: Bool

    init(supportsColors: Bool = true) {
        self.supportsColors = supportsColors
    }

    /// Start spinner with default "Thinking..." message
    func start() {
        self.start(message: "Thinking...")
    }

    /// Start spinner with custom message
    func start(message: String) {
        self.stop() // Ensure no previous spinner is running

        if self.supportsColors {
            self.spinner = Spinner(.dots, message, format: "{S} {T}")
        } else {
            // For environments without color support, use a minimal spinner
            self.spinner = Spinner(.dots, message, format: "{T}...")
        }

        self.spinner?.start()
    }

    /// Stop spinner without completion message
    func stop() {
        self.spinner?.clear()
        self.spinner = nil
    }

    /// Stop spinner with success message
    func success(_ message: String? = nil) {
        self.spinner?.success(message)
        self.spinner = nil
    }

    /// Stop spinner with error message
    func error(_ message: String? = nil) {
        self.spinner?.error(message)
        self.spinner = nil
    }

    /// Stop spinner with warning message
    func warning(_ message: String? = nil) {
        self.spinner?.warning(message)
        self.spinner = nil
    }

    /// Stop spinner with info message
    func info(_ message: String? = nil) {
        self.spinner?.info(message)
        self.spinner = nil
    }

    /// Update spinner message while running
    func updateMessage(_ message: String) {
        self.spinner?.message(message)
    }

    /// Stop with a brief delay for smoother transitions
    func stopWithDelay() async {
        do {
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
        } catch {}
        self.stop()
    }
}
