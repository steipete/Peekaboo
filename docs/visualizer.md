# Peekaboo Visual Feedback System

## Overview

The Peekaboo Visual Feedback System provides delightful, informative visual indicators for all agent actions. When the Peekaboo.app is running, CLI and MCP operations automatically get enhanced with animations and visual cues that help users understand what the agent is doing.

## Architecture

### Core Design
- **Integration**: Built directly into Peekaboo.app
- **Communication**: XPC service (`boo.peekaboo.visualizer`) for CLI → App communication
- **Fallback**: CLI/MCP work normally without visual feedback if app isn't running
- **Performance**: GPU-accelerated SwiftUI animations with minimal overhead

### Communication Flow
```
MCP Server → peekaboo CLI → XPC → Peekaboo.app → Visual Feedback
                    ↓
            (no app running)
                    ↓
            Text-only output
```

## Visual Feedback Designs

### Screenshot Capture 📸
- **Effect**: Subtle camera flash animation
- **Style**: White semi-transparent overlay that quickly fades
- **Duration**: 200ms (quick flash)
- **Coverage**: Only the captured area flashes (not full screen)
- **Intensity**: 20% opacity peak to avoid irritation

### Click Actions 🎯
- **Single Click**: Blue ripple effect from click point
- **Double Click**: Purple double-ripple animation
- **Right Click**: Orange ripple with context menu hint
- **Duration**: 500ms expanding ripple
- **Extra**: Small "click" label appears briefly

### Typing Feedback ⌨️
- **Style**: Floating keyboard widget at bottom center
- **Effect**: Keys light up as typed
- **Special Keys**: Visual representation (⏎, ⇥, ⌫)
- **Position**: Semi-transparent, doesn't block content
- **Duration**: Visible during typing + 500ms fade

### Scrolling 📜
- **Effect**: Directional arrows with motion blur
- **Style**: Animated arrows indicating scroll direction
- **Position**: At scroll location
- **Extra**: Scroll amount indicator (e.g., "3 lines")

### Mouse Movement 🖱️
- **Effect**: Glowing trail following mouse path
- **Style**: Fading particle trail
- **Color**: Soft blue glow
- **Duration**: Trail fades over 1 second

### Swipe/Drag Gestures 👆
- **Effect**: Animated path from start to end
- **Style**: Gradient line with directional arrow
- **Start/End**: Pulsing markers at endpoints
- **Duration**: Animation follows gesture speed

### Hotkeys ⌨️
- **Style**: Large key combination display
- **Position**: Center of screen
- **Format**: "⌘ + C", "⌃ + ⇧ + T"
- **Effect**: Keys appear with spring animation
- **Duration**: 1 second display + fade

### App Launch 🚀
- **Effect**: App icon bounces in from bottom
- **Style**: Icon + "Launching..." text
- **Animation**: Playful bounce effect
- **Duration**: Until app appears

### App Quit 🛑
- **Effect**: App icon shrinks and fades
- **Style**: Icon + "Quitting..." text
- **Animation**: Smooth scale down
- **Duration**: 500ms

### Window Operations 🪟
- **Move**: Dotted outline follows window
- **Resize**: Live dimension labels (e.g., "800×600")
- **Minimize**: Window shrinks to dock with trail
- **Close**: Red flash on window before close

### Menu Navigation 📋
- **Effect**: Sequential highlight of menu path
- **Style**: Blue glow on each menu item
- **Timing**: 200ms per menu level
- **Path**: Shows breadcrumb trail

### Dialog Interactions 💬
- **Effect**: Highlight dialog elements
- **Buttons**: Pulse when clicked
- **Text Fields**: Glow when focused
- **Style**: Attention-grabbing but not intrusive

### Space Switching 🚪
- **Effect**: Slide transition indicator
- **Style**: Arrow showing direction
- **Preview**: Mini preview of destination space
- **Duration**: Matches system animation

### Element Detection (See) 👁️
- **Effect**: All detected elements briefly highlight
- **Style**: Colored overlays with IDs (B1, T1, etc.)
- **Animation**: Fade in with slight scale
- **Duration**: 2 seconds before fade

## Implementation Details

### XPC Service

```swift
// In Peekaboo.app
@objc protocol VisualizerXPCProtocol {
    func showScreenshotFlash(in rect: CGRect, reply: @escaping (Bool) -> Void)
    func showClickFeedback(at point: CGPoint, type: String, reply: @escaping (Bool) -> Void)
    func showTypingFeedback(keys: [String], reply: @escaping (Bool) -> Void)
    func showScrollFeedback(at point: CGPoint, direction: String, amount: Int, reply: @escaping (Bool) -> Void)
    // ... other feedback methods
}
```

### Mach Service Name
- **Service ID**: `boo.peekaboo.visualizer`
- **Registered in**: Peekaboo.app's Info.plist
- **Connection from**: CLI via PeekabooCore

### SwiftUI Animation Components

Located in `/Apps/Mac/Peekaboo/Features/Visualizer/`:
- `ScreenshotFlashView.swift` - Camera flash effect
- `ClickAnimationView.swift` - Ripple effects
- `TypeAnimationView.swift` - Keyboard visualization
- `ScrollAnimationView.swift` - Scroll indicators
- `MouseTrailView.swift` - Mouse movement trails
- `HotkeyDisplayView.swift` - Key combination display
- ... (one file per animation type)

### Integration Points

1. **Agent Tools**: Each tool in `UIAutomationTools.swift` calls visualizer
2. **Overlay Manager**: Extended to handle animation layers
3. **Window Management**: Reuses existing overlay window system
4. **Performance**: Animations auto-cleanup after completion

## Configuration

### Environment Variables
```bash
PEEKABOO_VISUAL_FEEDBACK=false  # Disable all visual feedback
PEEKABOO_VISUAL_SCREENSHOTS=false  # Disable just screenshot flash
```

### User Preferences (in Peekaboo.app)
- Toggle visual feedback on/off
- Adjust animation speed
- Control effect intensity
- Per-action toggles

## Fun Details 🎉

### Screenshot Flash
- **Easter Egg**: Every 100th screenshot shows a tiny 👻 ghost in the flash
- **Sound**: Optional subtle camera shutter sound
- **Customization**: Users can adjust flash intensity

### Click Animations
- **Variety**: Different click patterns for different UI elements
- **Physics**: Ripples interact with screen edges
- **Trails**: Fast clicks create comet-like trails

### Typing Widget
- **Themes**: Multiple keyboard themes (classic, modern, ghostly)
- **Effects**: Keys have satisfying press animations
- **Speed**: Shows WPM for fun

### App Launch
- **Personality**: Each app can have custom launch animation
- **Sounds**: Optional playful sound effects
- **Progress**: Show actual launch progress if available

## Performance Considerations

1. **Lazy Loading**: Animations load on-demand
2. **GPU Acceleration**: All animations use Metal
3. **Memory Management**: Views removed after animation
4. **Battery Friendly**: Reduced effects on battery power
5. **Accessibility**: Respects "Reduce Motion" setting

## Security & Privacy

1. **No Screenshots**: Visual feedback doesn't capture screen content
2. **Local Only**: No data leaves the machine
3. **Permission Reuse**: Uses Peekaboo.app's existing permissions
4. **Sandboxed**: Runs within app sandbox

## Future Enhancements

1. **Themes**: User-created visual themes
2. **Sounds**: Optional sound effects
3. **Recording**: Save visual feedback as video
4. **Sharing**: Export automation demos with visuals
5. **AI Feedback**: Show agent's "thinking" visually

## Summary

The visual feedback system transforms Peekaboo agent operations from invisible automation into an engaging, understandable experience. By showing users exactly what the agent sees and does, we build trust and make automation accessible to everyone.

The playful touches (like the screenshot flash) add personality while remaining professional and non-intrusive. The system is designed to delight power users while helping newcomers understand automation.

Most importantly, it's completely optional - the CLI and MCP continue to work perfectly without it, making visual feedback a progressive enhancement rather than a requirement.

## Implementation Checklist

### Phase 1: Foundation (XPC & Infrastructure)

#### XPC Service Setup
- [ ] Create `VisualizerXPCProtocol.swift` in PeekabooCore
  - [ ] Define protocol with all feedback methods
  - [ ] Add proper NSSecureCoding support
  - [ ] Include error handling callbacks
- [ ] Add XPC service to Peekaboo.app
  - [ ] Update Info.plist with `boo.peekaboo.visualizer` service
  - [ ] Create `VisualizerXPCService.swift` implementation
  - [ ] Add XPC listener in AppDelegate
  - [ ] Test connection from CLI
- [ ] Create `VisualizationClient.swift` in PeekabooCore
  - [ ] Auto-detect if Peekaboo.app is running
  - [ ] Establish XPC connection
  - [ ] Implement fallback behavior
  - [ ] Add connection retry logic

#### Overlay Window Enhancement
- [ ] Extend `OverlayManager.swift`
  - [ ] Add animation layer management
  - [ ] Create animation queue system
  - [ ] Add cleanup timers for animations
  - [ ] Support multiple concurrent animations
- [ ] Create `VisualizerOverlayWindow.swift`
  - [ ] Configure for animation display
  - [ ] Set proper window level
  - [ ] Handle multi-screen setups
  - [ ] Add debug mode for testing

### Phase 2: Core Animation Components

#### Screenshot Flash Animation
- [ ] Create `ScreenshotFlashView.swift`
  - [ ] Implement 200ms flash animation
  - [ ] Add 20% opacity peak
  - [ ] Support custom flash regions
  - [ ] Add ghost emoji easter egg (every 100th)
- [ ] Integrate with screenshot service
  - [ ] Hook into `see` command
  - [ ] Hook into `image` command
  - [ ] Add configuration checks

#### Click Animations
- [ ] Create `ClickAnimationView.swift`
  - [ ] Single click (blue ripple)
  - [ ] Double click (purple double-ripple)
  - [ ] Right click (orange ripple)
  - [ ] Add click type labels
- [ ] Create physics system for ripples
  - [ ] Edge bounce effects
  - [ ] Ripple interference patterns
  - [ ] Trail effects for rapid clicks

#### Typing Feedback
- [ ] Create `TypeAnimationView.swift`
  - [ ] Floating keyboard widget
  - [ ] Key press animations
  - [ ] Special key representations
  - [ ] WPM counter
- [ ] Create keyboard themes
  - [ ] Classic theme
  - [ ] Modern theme
  - [ ] Ghostly theme
- [ ] Handle different keyboard layouts

#### Scroll Animations
- [ ] Create `ScrollAnimationView.swift`
  - [ ] Directional arrows
  - [ ] Motion blur effects
  - [ ] Scroll amount indicators
  - [ ] Smooth vs discrete scroll

### Phase 3: Advanced Animations

#### Mouse Movement
- [ ] Create `MouseTrailView.swift`
  - [ ] Particle trail system
  - [ ] Fading glow effect
  - [ ] Performance optimization
  - [ ] Trail customization

#### Swipe/Drag
- [ ] Create `SwipeAnimationView.swift`
  - [ ] Path drawing animation
  - [ ] Gradient effects
  - [ ] Start/end markers
  - [ ] Variable speed support

#### Hotkey Display
- [ ] Create `HotkeyDisplayView.swift`
  - [ ] Key combination formatting
  - [ ] Spring animations
  - [ ] Symbol rendering (⌘, ⌃, ⇧)
  - [ ] Multi-key sequences

#### App Lifecycle
- [ ] Create `AppLaunchAnimationView.swift`
  - [ ] Icon bounce effect
  - [ ] Progress indication
  - [ ] Custom per-app animations
- [ ] Create `AppQuitAnimationView.swift`
  - [ ] Shrink and fade effect
  - [ ] Status text display

### Phase 4: Window & System Animations

#### Window Operations
- [ ] Create `WindowOperationView.swift`
  - [ ] Move operation (dotted outline)
  - [ ] Resize operation (dimension labels)
  - [ ] Minimize animation (trail to dock)
  - [ ] Close animation (red flash)

#### Menu Navigation
- [ ] Create `MenuHighlightView.swift`
  - [ ] Sequential item highlighting
  - [ ] Breadcrumb trail
  - [ ] Timing coordination
  - [ ] Submenu support

#### Dialog Interactions
- [ ] Create `DialogFeedbackView.swift`
  - [ ] Button pulse effects
  - [ ] Text field glow
  - [ ] Focus indicators
  - [ ] Selection highlights

#### Space Switching
- [ ] Create `SpaceTransitionView.swift`
  - [ ] Slide indicators
  - [ ] Direction arrows
  - [ ] Mini space previews
  - [ ] Transition timing

### Phase 5: Integration

#### Tool Integration
- [ ] Update `UIAutomationTools.swift`
  - [ ] Add visualizer calls to click tool
  - [ ] Add visualizer calls to type tool
  - [ ] Add visualizer calls to scroll tool
  - [ ] Add visualizer calls to swipe tool
- [ ] Update `VisionTools.swift`
  - [ ] Add screenshot flash to see command
  - [ ] Add element highlight animations
- [ ] Update `ApplicationTools.swift`
  - [ ] Add app launch/quit animations
- [ ] Update `WindowManagementTools.swift`
  - [ ] Add window operation animations
- [ ] Update `MenuTools.swift`
  - [ ] Add menu navigation highlights
- [ ] Update `DialogTools.swift`
  - [ ] Add dialog interaction feedback

#### Configuration System
- [ ] Add environment variable support
  - [ ] `PEEKABOO_VISUAL_FEEDBACK`
  - [ ] `PEEKABOO_VISUAL_SCREENSHOTS`
  - [ ] Per-action toggles
- [ ] Add app preferences UI
  - [ ] Master on/off toggle
  - [ ] Animation speed slider
  - [ ] Effect intensity controls
  - [ ] Per-action checkboxes

### Phase 6: Performance & Polish

#### Optimization
- [ ] Profile animation performance
  - [ ] GPU usage monitoring
  - [ ] Memory leak detection
  - [ ] Frame rate analysis
- [ ] Implement animation pooling
- [ ] Add battery-saving mode
- [ ] Respect "Reduce Motion" setting

#### Testing
- [ ] Unit tests for XPC communication
- [ ] Animation timing tests
- [ ] Multi-screen testing
- [ ] Performance benchmarks
- [ ] Accessibility testing

#### Documentation
- [ ] API documentation for visualizer protocol
- [ ] Animation customization guide
- [ ] Troubleshooting guide
- [ ] Video demos of all animations

### Phase 7: Fun Features

#### Easter Eggs
- [ ] Screenshot ghost emoji (every 100th)
- [ ] Special animations for specific apps
- [ ] Hidden keyboard themes
- [ ] Achievement system

#### Sound Effects (Optional)
- [ ] Camera shutter for screenshots
- [ ] Click sounds
- [ ] Typing sounds
- [ ] Success/failure sounds

#### Advanced Features
- [ ] Animation recording system
- [ ] Custom theme editor
- [ ] Animation export for demos
- [ ] AI "thinking" visualization

### Phase 8: Release

#### Final Testing
- [ ] Full integration test suite
- [ ] Beta testing with users
- [ ] Performance validation
- [ ] Security review

#### Documentation
- [ ] Update README.md
- [ ] Create tutorial videos
- [ ] Write blog post
- [ ] Update website

#### Distribution
- [ ] Ensure visualizer works with MCP
- [ ] Test npm package integration
- [ ] Verify CLI fallback behavior
- [ ] Release notes

## Success Criteria

- [ ] All agent actions have visual feedback
- [ ] Zero performance impact when disabled
- [ ] < 5% CPU usage during animations
- [ ] Works on all macOS versions (14.0+)
- [ ] Graceful fallback without Peekaboo.app
- [ ] Delightful user experience
- [ ] Professional appearance
- [ ] Fun but not distracting