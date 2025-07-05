#!/usr/bin/env swift

// Test script for InputEvents functionality
// Run with: swift test-input-events.swift

import Foundation
import CoreGraphics

// Test 1: Click at specific coordinates
print("Test 1: Testing mouse click at (500, 500)")
print("Please position a clickable element at coordinates 500, 500")
print("Starting in 3 seconds...")
Thread.sleep(forTimeInterval: 3)

// Click at center of screen
let clickPoint = CGPoint(x: 500, y: 500)
let mouseDown = CGEvent(
    mouseEventSource: nil,
    mouseType: .leftMouseDown,
    mouseCursorPosition: clickPoint,
    mouseButton: .left
)
mouseDown?.post(tap: .cghidEventTap)

Thread.sleep(forTimeInterval: 0.05)

let mouseUp = CGEvent(
    mouseEventSource: nil,
    mouseType: .leftMouseUp,
    mouseCursorPosition: clickPoint,
    mouseButton: .left
)
mouseUp?.post(tap: .cghidEventTap)

print("✅ Click event posted")

// Test 2: Type some text
print("\nTest 2: Testing keyboard input")
print("Focus a text field and wait 3 seconds...")
Thread.sleep(forTimeInterval: 3)

let testString = "Hello Peekaboo!"
for char in testString {
    let source = CGEventSource(stateID: .hidSystemState)
    let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
    event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [char.utf16.first!])
    event?.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
}

print("✅ Typed: \(testString)")

// Test 3: Keyboard shortcut (Cmd+A)
print("\nTest 3: Testing keyboard shortcut (Cmd+A)")
Thread.sleep(forTimeInterval: 1)

// Press Cmd
let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true)
cmdDown?.flags = .maskCommand
cmdDown?.post(tap: .cghidEventTap)

// Press A
let aDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true)
aDown?.flags = .maskCommand
aDown?.post(tap: .cghidEventTap)

Thread.sleep(forTimeInterval: 0.1)

// Release A
let aUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: false)
aUp?.flags = .maskCommand
aUp?.post(tap: .cghidEventTap)

// Release Cmd
let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false)
cmdUp?.post(tap: .cghidEventTap)

print("✅ Cmd+A shortcut executed")

print("\nAll tests completed!")
print("Note: You should have seen:")
print("1. A click at position (500, 500)")
print("2. 'Hello Peekaboo!' typed in a text field")
print("3. All text selected (Cmd+A)")