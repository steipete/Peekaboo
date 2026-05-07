import Foundation

// MARK: - Process Command Types

/// Type-safe parameters for process commands
public enum ProcessCommandParameters: Codable, Sendable {
    /// Click command parameters
    case click(ClickParameters)
    /// Type command parameters
    case type(TypeParameters)
    /// Hotkey command parameters
    case hotkey(HotkeyParameters)
    /// Scroll command parameters
    case scroll(ScrollParameters)
    /// Menu click command parameters
    case menuClick(MenuClickParameters)
    /// Dialog command parameters
    case dialog(DialogParameters)
    /// Launch app command parameters
    case launchApp(LaunchAppParameters)
    /// Find element command parameters
    case findElement(FindElementParameters)
    /// Screenshot command parameters
    case screenshot(ScreenshotParameters)
    /// Focus window command parameters
    case focusWindow(FocusWindowParameters)
    /// Resize window command parameters
    case resizeWindow(ResizeWindowParameters)
    /// Swipe command parameters
    case swipe(SwipeParameters)
    /// Drag command parameters
    case drag(DragParameters)
    /// Sleep command parameters
    case sleep(SleepParameters)
    /// Dock command parameters
    case dock(DockParameters)
    /// Clipboard command parameters
    case clipboard(ClipboardParameters)
    /// Generic parameters (for backward compatibility during migration)
    case generic([String: String])
}

/// Type-safe output for process commands
public enum ProcessCommandOutput: Codable, Sendable {
    /// Success with optional message
    case success(String?)
    /// Error with message
    case error(String)
    /// Screenshot result
    case screenshot(ScreenshotOutput)
    /// Element info
    case element(ElementOutput)
    /// Window info
    case window(WindowOutput)
    /// List of items
    case list([String])
    /// Structured data
    case data([String: ProcessCommandOutput])
}
