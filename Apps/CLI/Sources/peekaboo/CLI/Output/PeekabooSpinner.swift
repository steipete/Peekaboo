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
        start(message: "Thinking...")
    }
    
    /// Start spinner with custom message
    func start(message: String) {
        stop() // Ensure no previous spinner is running
        
        if supportsColors {
            spinner = Spinner(.dots, message, format: "{S} {T}")
        } else {
            // For environments without color support, use a minimal spinner
            spinner = Spinner(.dots, message, format: "{T}...")
        }
        
        spinner?.start()
    }
    
    /// Stop spinner without completion message
    func stop() {
        spinner?.clear()
        spinner = nil
    }
    
    /// Stop spinner with success message
    func success(_ message: String? = nil) {
        spinner?.success(message)
        spinner = nil
    }
    
    /// Stop spinner with error message
    func error(_ message: String? = nil) {
        spinner?.error(message)
        spinner = nil
    }
    
    /// Stop spinner with warning message
    func warning(_ message: String? = nil) {
        spinner?.warning(message)
        spinner = nil
    }
    
    /// Stop spinner with info message
    func info(_ message: String? = nil) {
        spinner?.info(message)
        spinner = nil
    }
    
    /// Update spinner message while running
    func updateMessage(_ message: String) {
        spinner?.message(message)
    }
    
    /// Stop with a brief delay for smoother transitions
    func stopWithDelay() async {
        do {
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
        } catch {}
        stop()
    }
}