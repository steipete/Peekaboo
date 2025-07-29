# Animated SF Symbol Icons Implementation

This document summarizes the implementation of animated SF Symbol icons for tool executions in the Mac app.

## Overview

Following the techniques from Daniel Saidi's blog post on SF Symbol animations, we've implemented context-aware animated icons that provide visual feedback while tools are running.

## Implementation Details

### AnimatedToolIcon Component
- **File**: `/Apps/Mac/Peekaboo/Features/Main/AnimatedToolIcon.swift`
- **Purpose**: Displays animated SF Symbols for each tool type
- **Fallback**: Static text icons for macOS < 14.0

### Animation Types by Tool Category

#### 🎯 Bounce Effects
- **Tools**: `see`, `screenshot`, `click`, `launch_app`, `quit_app`
- **Symbol Examples**: `camera.viewfinder`, `cursorarrow.click`, `app.dashed`
- **Effect**: Elements bounce to indicate action completion

#### 💫 Pulse Effects  
- **Tools**: `type`, `hotkey`, `permissions`, `find_element`
- **Symbol Examples**: `keyboard`, `command`, `lock.shield`
- **Effect**: Rhythmic pulsing to show ongoing input

#### 🌈 Variable Color Effects
- **Tools**: `scroll`, `shell`
- **Symbol Examples**: `arrow.up.and.down.circle`, `terminal`
- **Effect**: Color cycling to indicate processing

#### 〰️ Wiggle Effects
- **Tools**: `resize_window`, `move_window`, `drag`, `swipe`
- **Symbol Examples**: `arrow.up.left.and.down.right.magnifyingglass`, `hand.draw`
- **Effect**: Wiggling motion for manipulation actions

#### 🔄 Rotation Effects
- **Tools**: `wait`, `sleep`, default tools
- **Symbol Examples**: `clock`, `gearshape`
- **Effect**: Continuous rotation for time-based operations

#### ✨ Appear Effects
- **Tools**: `list_*`, `focus_window`, `space`
- **Symbol Examples**: `list.bullet.rectangle`, `macwindow.on.rectangle`
- **Effect**: Fade-in animation for discovery actions

## Color Coding

- **Blue**: Vision/capture tools (`see`, `screenshot`)
- **Purple**: Click interactions
- **Indigo**: Text input
- **Green**: Launch/success operations
- **Red**: Quit/stop operations
- **Orange**: Shell commands
- **Yellow**: Information requests
- **Primary**: Default tools

## Usage

The animated icons are automatically displayed in `ToolExecutionRow` when a tool is running:

```swift
ToolIcon(
    toolName: execution.toolName,
    isRunning: execution.status == .running
)
```

## Testing

Run `./test_animated_icons.sh` to see various tool animations in action.

## Benefits

1. **Visual Feedback**: Users can immediately see which tools are running
2. **Tool Recognition**: Unique animations help identify tool types at a glance
3. **Status Indication**: Animation state clearly shows running vs completed
4. **Modern Feel**: Native SF Symbol animations provide a polished, system-integrated look
5. **Performance**: Lightweight animations with no custom drawing code

## Future Enhancements

- Custom animation timing for long-running tools
- Success/failure animation transitions
- Tool-specific animation parameters
- Additional SF Symbol variations for tool subtypes