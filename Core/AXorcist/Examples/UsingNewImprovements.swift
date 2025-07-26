//
//  UsingNewImprovements.swift
//  AXorcist Examples
//
//  Examples demonstrating the new improvements to AXorcist
//

import ApplicationServices
import Foundation

// MARK: - Example 1: Using Static Factory Methods

@MainActor
func exampleStaticFactoryMethods() {
    // Old way:
    // let systemWide = Element(AXUIElementCreateSystemWide())

    // New way:
    let systemWide = Element(AXUIElement.systemWide)

    // Get focused application
    if let focusedApp = AXUIElement.focusedApplication() {
        let appElement = Element(focusedApp)
        print("Focused app: \(appElement.title() ?? "Unknown")")
    }

    // Get frontmost application
    if let frontmostApp = AXUIElement.frontmostApplication() {
        let appElement = Element(frontmostApp)
        print("Frontmost app: \(appElement.title() ?? "Unknown")")
    }

    // Get element at position
    if let app = AXUIElement.frontmostApplication(),
       let element = AXUIElement.elementAtPosition(in: app, x: 500, y: 300)
    {
        let elem = Element(element)
        print("Element at (500, 300): \(elem.role() ?? "Unknown")")
    }
}

// MARK: - Example 2: Using Convenience Attributes

@MainActor
func exampleConvenienceAttributes() {
    guard let frontmostApp = frontmostApplicationElement() else { return }

    // Get all windows with new convenience method
    if let windows = frontmostApp.windows() {
        for window in windows {
            // Use new position and size methods
            if let position = window.position(),
               let size = window.size()
            {
                print("Window at \(position) with size \(size)")

                // Get frame as CGRect
                if let frame = window.frame() {
                    print("Window frame: \(frame)")
                }
            }

            // Check window state
            if let isMinimized = window.isMinimized() {
                print("Window minimized: \(isMinimized)")
            }

            // Modify window position
            let newPosition = CGPoint(x: 100, y: 100)
            let error = window.setPosition(newPosition)
            if error == .success {
                print("Successfully moved window")
            }
        }
    }
}

// MARK: - Example 3: Using AXObserverCenter

@MainActor
func exampleObserverCenter() {
    guard let app = frontmostApplicationElement(),
          let pid = app.pid() else { return }

    // Set up observer with new center
    AXObserverCenter.shared.handler = { pid, notification, _, element, _ in
        print("Notification: \(notification) from PID: \(pid)")

        let elem = Element(element)
        if let title = elem.title() {
            print("Element: \(title)")
        }
    }

    // Add multiple notifications
    let notifications = [
        kAXFocusedUIElementChangedNotification,
        kAXWindowCreatedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
    ]

    for notification in notifications {
        let error = AXObserverCenter.shared.addObserver(
            pid: pid,
            notificationKey: notification as String
        )
        if error == .success {
            print("Added observer for \(notification)")
        }
    }

    // Later, remove all observers for the app
    // AXObserverCenter.shared.removeAllObservers(for: pid)
}

// MARK: - Example 4: Using Modern AXAction Enum

@MainActor
func exampleModernActions() {
    guard let app = frontmostApplicationElement() else { return }

    do {
        // Old way (still supported):
        // try app.performAction("AXPress")
        // try app.performAction(AXActionNames.kAXRaiseAction)

        // New way with cleaner enum syntax:
        try app.performAction(.press)
        print("✅ Pressed element successfully")

        try app.performAction(.raise)
        print("✅ Raised element successfully")

        // All available actions:
        let availableActions: [AXAction] = [
            .press, .increment, .decrement, .confirm, .cancel,
            .showMenu, .pick, .raise, .setValue,
        ]

        print("Available actions: \(availableActions.map(\.rawValue).joined(separator: ", "))")

    } catch {
        print("❌ Action failed: \(error)")
    }
}

// MARK: - Example 5: Using Enhanced Error Handling

@MainActor
func exampleErrorHandling() {
    guard let app = frontmostApplicationElement() else { return }

    do {
        // Perform action with automatic error throwing
        try app.performAction(.press)
        print("Action performed successfully")
    } catch let systemError as AccessibilitySystemError {
        // Convert to more descriptive error
        let accessibilityError = systemError.axError.toAccessibilityError(context: "Pressing button")
        print("Error: \(accessibilityError)")
    } catch {
        print("Unexpected error: \(error)")
    }
}

// MARK: - Example 6: Using AXPermissions with Async/Await

func examplePermissions() async {
    // Check permissions without prompting
    if AXPermissionHelpers.hasAccessibilityPermissions() {
        print("Accessibility permissions granted")
    } else {
        print("Accessibility permissions not granted")
    }

    // Request permissions with prompt if needed (async)
    let granted = await AXPermissionHelpers.requestPermissions()
    if granted {
        print("User granted permissions")
    } else {
        print("User denied permissions")
    }

    // Monitor permission changes with AsyncStream
    Task {
        for await hasPermissions in AXPermissionHelpers.permissionChanges() {
            print("Permission status changed: \(hasPermissions)")
        }
    }
}

// MARK: - Example 7: Using Window Info Helper

@MainActor
func exampleWindowInfo() {
    // Get all visible windows
    if let windows = WindowInfoHelper.getVisibleWindows() {
        for window in windows {
            if let name = window[kCGWindowName as String] as? String,
               let pid = window[kCGWindowOwnerPID as String] as? Int,
               let windowID = window[kCGWindowNumber as String] as? Int
            {
                print("Window '\(name)' (ID: \(windowID)) owned by PID: \(pid)")
            }
        }
    }

    // Get window bounds
    if let bounds = WindowInfoHelper.getWindowBounds(windowID: 12345) {
        print("Window bounds: \(bounds)")
    }
}

// MARK: - Example 8: Using AXValue Extensions

@MainActor
func exampleAXValueExtensions() {
    guard let window = AXUIElement.focusedWindowInFocusedApplication() else { return }

    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)

    if error == .success, let axValue = value as? AXValue {
        // Old way:
        // var point = CGPoint.zero
        // AXValueGetValue(axValue, .cgPoint, &point)

        // New way:
        if let point = axValue.cgPoint() {
            print("Window position: \(point)")
        }

        // Or use generic value() method
        if let anyValue = axValue.value() {
            print("Value: \(anyValue)")
        }
    }
}

// MARK: - Example 9: Batch Operations with Better Error Handling

@MainActor
func exampleBatchOperations() {
    guard let app = frontmostApplicationElement() else { return }

    // Get multiple attributes efficiently
    let attributesToCheck = [
        (attr: Attribute<String>.title, name: "Title"),
        (attr: Attribute<String>.role, name: "Role"),
        (attr: Attribute<Bool>.enabled, name: "Enabled"),
        (attr: Attribute<Bool>.focused, name: "Focused"),
    ]

    for (attribute, name) in attributesToCheck {
        if let value = app.attribute(attribute) {
            print("\(name): \(value)")
        }
    }
}

// MARK: - Example 10: Using Running Application Helper

func exampleRunningApplications() {
    // Get all running applications
    let allApps = RunningApplicationHelper.allApplications()
    print("Running applications: \(allApps.count)")

    // Find specific app by bundle ID
    let safariApps = RunningApplicationHelper.applications(withBundleIdentifier: "com.apple.Safari")
    if !safariApps.isEmpty {
        print("Safari is running")
    }

    // Get current app info
    let currentPID = RunningApplicationHelper.currentPID
    print("Current app PID: \(currentPID)")
}

// MARK: - Main Example Runner

@MainActor
func runAllExamples() async {
    print("=== Static Factory Methods ===")
    exampleStaticFactoryMethods()

    print("\n=== Convenience Attributes ===")
    exampleConvenienceAttributes()

    print("\n=== Observer Center ===")
    exampleObserverCenter()

    print("\n=== Modern Actions ===")
    exampleModernActions()

    print("\n=== Error Handling ===")
    exampleErrorHandling()

    print("\n=== Permissions ===")
    await examplePermissions()

    print("\n=== Window Info ===")
    exampleWindowInfo()

    print("\n=== AXValue Extensions ===")
    exampleAXValueExtensions()

    print("\n=== Batch Operations ===")
    exampleBatchOperations()

    print("\n=== Running Applications ===")
    exampleRunningApplications()
}
