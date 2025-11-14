---
summary: 'Review Implementing Liquid Glass Design in AppKit guidance'
read_when:
  - 'planning work related to implementing liquid glass design in appkit'
  - 'debugging or extending features described here'
---

# Implementing Liquid Glass Design in AppKit

## Overview

Liquid Glass is a dynamic material design introduced by Apple that combines the optical properties of glass with a sense of fluidity. It creates a modern, immersive user interface by:

- Blurring content behind it
- Reflecting color and light from surrounding content
- Reacting to touch and pointer interactions in real time
- Creating fluid animations and transitions between elements

Liquid Glass is available across Apple platforms, with specific implementations in SwiftUI, UIKit, and AppKit. This guide focuses on implementing Liquid Glass design in AppKit applications.

## Key Classes

AppKit provides two main classes for implementing Liquid Glass design:

### NSGlassEffectView

`NSGlassEffectView` is the primary class for creating Liquid Glass effects in AppKit. It embeds its content view in a dynamic glass effect.

```swift
@MainActor class NSGlassEffectView: NSView
```

### NSGlassEffectContainerView

`NSGlassEffectContainerView` allows similar `NSGlassEffectView` instances in close proximity to merge together, creating fluid transitions and improving rendering performance.

```swift
@MainActor class NSGlassEffectContainerView: NSView
```

## Basic Implementation

### Creating a Simple Glass Effect View

```swift
import AppKit

class MyViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a glass effect view
        let glassView = NSGlassEffectView(frame: NSRect(x: 20, y: 20, width: 200, height: 100))
        
        // Create content to display inside the glass effect
        let label = NSTextField(labelWithString: "Liquid Glass")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        
        // Set the content view
        glassView.contentView = label
        
        // Add constraints to center the label
        if let contentView = glassView.contentView {
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
        
        // Add the glass view to your view hierarchy
        view.addSubview(glassView)
    }
}
```

## Customizing Glass Effect Views

### Setting Corner Radius

The `cornerRadius` property controls the curvature of all corners of the glass effect.

```swift
// Create a glass effect view with rounded corners
let glassView = NSGlassEffectView(frame: NSRect(x: 20, y: 20, width: 200, height: 100))
glassView.cornerRadius = 16.0
```

### Adding a Tint Color

The `tintColor` property modifies the background and effect to tint toward the provided color.

```swift
// Create a glass effect view with a blue tint
let glassView = NSGlassEffectView(frame: NSRect(x: 20, y: 20, width: 200, height: 100))
glassView.tintColor = NSColor.systemBlue.withAlphaComponent(0.3)
```

### Creating a Custom Button with Glass Effect

```swift
class GlassButton: NSButton {
    private let glassView = NSGlassEffectView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGlassEffect()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassEffect()
    }
    
    private func setupGlassEffect() {
        // Configure the button
        self.title = "Glass Button"
        self.bezelStyle = .rounded
        self.isBordered = false
        
        // Configure the glass view
        glassView.frame = self.bounds
        glassView.autoresizingMask = [.width, .height]
        glassView.cornerRadius = 8.0
        
        // Insert the glass view below the button's content
        self.addSubview(glassView, positioned: .below, relativeTo: nil)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Add tracking area for hover effects
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Change appearance on hover
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            glassView.animator().tintColor = NSColor.systemBlue.withAlphaComponent(0.2)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // Restore original appearance
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            glassView.animator().tintColor = nil
        }
    }
}
```

## Working with NSGlassEffectContainerView

### Creating a Container for Multiple Glass Views

```swift
func setupGlassContainer() {
    // Create a container view
    let containerView = NSGlassEffectContainerView(frame: NSRect(x: 20, y: 20, width: 400, height: 200))
    
    // Set spacing to control when glass effects merge
    containerView.spacing = 40.0
    
    // Create a content view to hold our glass views
    let contentView = NSView(frame: containerView.bounds)
    contentView.autoresizingMask = [.width, .height]
    containerView.contentView = contentView
    
    // Create first glass view
    let glassView1 = NSGlassEffectView(frame: NSRect(x: 20, y: 50, width: 150, height: 100))
    glassView1.cornerRadius = 12.0
    let label1 = NSTextField(labelWithString: "Glass View 1")
    label1.translatesAutoresizingMaskIntoConstraints = false
    glassView1.contentView = label1
    
    // Create second glass view
    let glassView2 = NSGlassEffectView(frame: NSRect(x: 190, y: 50, width: 150, height: 100))
    glassView2.cornerRadius = 12.0
    let label2 = NSTextField(labelWithString: "Glass View 2")
    label2.translatesAutoresizingMaskIntoConstraints = false
    glassView2.contentView = label2
    
    // Add glass views to the content view
    contentView.addSubview(glassView1)
    contentView.addSubview(glassView2)
    
    // Center labels in their respective glass views
    if let contentView1 = glassView1.contentView, let contentView2 = glassView2.contentView {
        NSLayoutConstraint.activate([
            label1.centerXAnchor.constraint(equalTo: contentView1.centerXAnchor),
            label1.centerYAnchor.constraint(equalTo: contentView1.centerYAnchor),
            label2.centerXAnchor.constraint(equalTo: contentView2.centerXAnchor),
            label2.centerYAnchor.constraint(equalTo: contentView2.centerYAnchor)
        ])
    }
    
    // Add the container to your view hierarchy
    view.addSubview(containerView)
}
```

### Animating Glass Views in a Container

```swift
func animateGlassViews() {
    // Assuming we have glassView1 and glassView2 in a container
    
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.5
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Animate the position of glassView2 to move closer to glassView1
        // This will trigger the merging effect when they get within the container's spacing
        glassView2.animator().frame = NSRect(x: 100, y: 50, width: 150, height: 100)
    }
}
```

## Creating Interactive Glass Effects

### Responding to Mouse Events

```swift
class InteractiveGlassView: NSGlassEffectView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }
    
    private func setupTracking() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Enhance the glass effect on hover
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().tintColor = NSColor.systemBlue.withAlphaComponent(0.2)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        // Restore original appearance
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().tintColor = nil
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        // Create subtle interactive effects based on mouse position
        let locationInView = convert(event.locationInWindow, from: nil)
        let normalizedX = locationInView.x / bounds.width
        let normalizedY = locationInView.y / bounds.height
        
        // Example: Adjust corner radius based on mouse position
        let newRadius = 8.0 + (normalizedX * 8.0)
        cornerRadius = newRadius
    }
}
```

## Creating a Toolbar with Liquid Glass Effect

```swift
func setupToolbarWithGlassEffect() {
    // Create a window
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered,
                         defer: false)
    
    // Create a custom toolbar
    let toolbar = NSToolbar(identifier: "GlassToolbar")
    toolbar.displayMode = .iconAndLabel
    toolbar.delegate = self // Implement NSToolbarDelegate
    
    // Set the toolbar on the window
    window.toolbar = toolbar
    
    // Create a glass effect view for the toolbar area
    let toolbarHeight: CGFloat = 50.0
    let glassView = NSGlassEffectView(frame: NSRect(x: 0, y: window.contentView!.bounds.height - toolbarHeight,
                                                  width: window.contentView!.bounds.width, height: toolbarHeight))
    glassView.autoresizingMask = [.width, .minYMargin]
    
    // Add the glass view to the window's content view
    window.contentView?.addSubview(glassView)
    
    // Make the window visible
    window.makeKeyAndOrderFront(nil)
}

// Implement NSToolbarDelegate methods
extension MyViewController: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        // Create toolbar items
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Action"
        item.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
        item.action = #selector(toolbarItemClicked(_:))
        return item
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return ["item1", "item2", "item3"].map { NSToolbarItem.Identifier($0) }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
    
    @objc func toolbarItemClicked(_ sender: Any) {
        // Handle toolbar item clicks
    }
}
```

## Best Practices

### Performance Considerations

1. **Use NSGlassEffectContainerView for multiple glass views**
   - This reduces the number of rendering passes required
   - Improves performance when multiple glass effects are used

2. **Limit the number of glass effects**
   - Liquid Glass effects require significant GPU resources
   - Use them strategically for important UI elements

3. **Consider view hierarchy**
   - Only the contentView of NSGlassEffectView is guaranteed to be inside the glass effect
   - Arbitrary subviews may not have consistent z-order behavior

### Design Guidelines

1. **Maintain appropriate spacing**
   - Set the spacing property on NSGlassEffectContainerView to control when effects merge
   - Default value (0) is suitable for batch processing while avoiding distortion

2. **Use corner radius appropriately**
   - Match corner radius to your app's design language
   - Consider using system-standard corner radii for consistency

3. **Apply tint colors judiciously**
   - Subtle tints work best for maintaining the glass aesthetic
   - Use tints to indicate state changes or interactive elements

4. **Create smooth transitions**
   - Animate position changes to create fluid merging effects
   - Use standard animation durations for consistency

## References

- [AppKit Documentation: NSGlassEffectView](https://developer.apple.com/documentation/AppKit/NSGlassEffectView)
- [AppKit Documentation: NSGlassEffectContainerView](https://developer.apple.com/documentation/AppKit/NSGlassEffectContainerView)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Landmarks: Building an app with Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Landmarks-Building-an-app-with-Liquid-Glass)