# Ghost Animation System

This directory contains the SwiftUI-based ghost animation system for Peekaboo's menu bar icon.

## Components

### GhostAnimationView.swift
- SwiftUI view that renders an animated ghost using Canvas
- Features:
  - Vertical floating motion (±3 pixels) with sine wave movement
  - Breathing effect with opacity variations (0.7-1.0)
  - Wavy bottom edge animation
  - Light/dark mode support
  - Optimized rendering with `drawingGroup()`

### MenuBarAnimationController.swift
- Manages animation timing and state
- Features:
  - Adaptive frame rate (30fps when animating, 15fps for subtle movement)
  - Icon caching to reduce CPU usage
  - Smooth start/stop transitions
  - Integration with PeekabooAgent's processing state

### StatusBarController.swift
- Updated to use the new animation system
- Removed dependency on ghost.peek1/2/3 image assets
- Observes agent state and triggers animations accordingly

## Animation Details

**Movement Pattern:**
- Vertical float: ±3 pixels amplitude
- Duration: 2.5 seconds per full cycle
- Easing: EaseInOut for smooth motion

**Breathing Effect:**
- Opacity range: 0.7 to 1.0
- Duration: 2.0 seconds (80% of float cycle for offset)
- Creates organic, lifelike appearance

**Performance:**
- Icon cache reduces rendering overhead
- Quantized animation values minimize cache misses
- Adaptive timing reduces CPU usage when idle
- Main thread execution (required for AppKit)

## Usage

The animation automatically starts when the agent begins processing and stops when complete. No manual intervention needed - it's all handled through observation of the agent's `isProcessing` property.