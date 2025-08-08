//
//  NSScreen+MouseLocation.swift
//  Peekaboo
//
//  Extensions for NSScreen to handle mouse location and screen targeting
//

import AppKit

extension NSScreen {
    /// Get the screen that contains the current mouse cursor position
    static var mouseScreen: NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main ?? NSScreen.screens.first!
    }
    
    /// Get the screen that contains a specific point
    /// - Parameter point: The point to check
    /// - Returns: The screen containing the point, or the main screen as fallback
    static func screen(containing point: CGPoint) -> NSScreen {
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens.first!
    }
    
    /// Check if this screen contains the current mouse cursor
    var containsMouse: Bool {
        let mouseLocation = NSEvent.mouseLocation
        return self.frame.contains(mouseLocation)
    }
}