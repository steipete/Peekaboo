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
    /// Generic parameters (for backward compatibility during migration)
    case generic([String: String])

    // MARK: - Parameter Types

    public struct ClickParameters: Codable, Sendable {
        public let x: Double?
        public let y: Double?
        public let label: String?
        public let app: String?
        public let button: String?
        public let modifiers: [String]?

        public init(
            x: Double? = nil,
            y: Double? = nil,
            label: String? = nil,
            app: String? = nil,
            button: String? = nil,
            modifiers: [String]? = nil)
        {
            self.x = x
            self.y = y
            self.label = label
            self.app = app
            self.button = button
            self.modifiers = modifiers
        }
    }

    public struct TypeParameters: Codable, Sendable {
        public let text: String
        public let app: String?
        public let field: String?
        public let clearFirst: Bool?
        public let pressEnter: Bool?

        public init(
            text: String,
            app: String? = nil,
            field: String? = nil,
            clearFirst: Bool? = nil,
            pressEnter: Bool? = nil)
        {
            self.text = text
            self.app = app
            self.field = field
            self.clearFirst = clearFirst
            self.pressEnter = pressEnter
        }
    }

    public struct HotkeyParameters: Codable, Sendable {
        public let key: String
        public let modifiers: [String]
        public let app: String?

        public init(key: String, modifiers: [String], app: String? = nil) {
            self.key = key
            self.modifiers = modifiers
            self.app = app
        }
    }

    public struct ScrollParameters: Codable, Sendable {
        public let direction: String
        public let amount: Int?
        public let app: String?
        public let target: String?

        public init(direction: String, amount: Int? = nil, app: String? = nil, target: String? = nil) {
            self.direction = direction
            self.amount = amount
            self.app = app
            self.target = target
        }
    }

    public struct MenuClickParameters: Codable, Sendable {
        public let menuPath: [String]
        public let app: String?

        public init(menuPath: [String], app: String? = nil) {
            self.menuPath = menuPath
            self.app = app
        }
    }

    public struct DialogParameters: Codable, Sendable {
        public let action: String
        public let buttonLabel: String?
        public let inputText: String?
        public let fieldLabel: String?

        public init(action: String, buttonLabel: String? = nil, inputText: String? = nil, fieldLabel: String? = nil) {
            self.action = action
            self.buttonLabel = buttonLabel
            self.inputText = inputText
            self.fieldLabel = fieldLabel
        }
    }

    public struct LaunchAppParameters: Codable, Sendable {
        public let appName: String
        public let action: String?
        public let waitForLaunch: Bool?
        public let bringToFront: Bool?
        public let force: Bool?

        public init(
            appName: String,
            action: String? = nil,
            waitForLaunch: Bool? = nil,
            bringToFront: Bool? = nil,
            force: Bool? = nil)
        {
            self.appName = appName
            self.action = action
            self.waitForLaunch = waitForLaunch
            self.bringToFront = bringToFront
            self.force = force
        }
    }

    public struct FindElementParameters: Codable, Sendable {
        public let label: String?
        public let identifier: String?
        public let type: String?
        public let app: String?

        public init(label: String? = nil, identifier: String? = nil, type: String? = nil, app: String? = nil) {
            self.label = label
            self.identifier = identifier
            self.type = type
            self.app = app
        }
    }

    public struct ScreenshotParameters: Codable, Sendable {
        public let path: String
        public let app: String?
        public let window: String?
        public let display: Int?
        public let mode: String?
        public let annotate: Bool?

        public init(
            path: String,
            app: String? = nil,
            window: String? = nil,
            display: Int? = nil,
            mode: String? = nil,
            annotate: Bool? = nil)
        {
            self.path = path
            self.app = app
            self.window = window
            self.display = display
            self.mode = mode
            self.annotate = annotate
        }
    }

    public struct FocusWindowParameters: Codable, Sendable {
        public let app: String?
        public let title: String?
        public let index: Int?

        public init(app: String? = nil, title: String? = nil, index: Int? = nil) {
            self.app = app
            self.title = title
            self.index = index
        }
    }

    public struct ResizeWindowParameters: Codable, Sendable {
        public let width: Int?
        public let height: Int?
        public let x: Int?
        public let y: Int?
        public let app: String?
        public let maximize: Bool?
        public let minimize: Bool?

        public init(
            width: Int? = nil,
            height: Int? = nil,
            x: Int? = nil,
            y: Int? = nil,
            app: String? = nil,
            maximize: Bool? = nil,
            minimize: Bool? = nil)
        {
            self.width = width
            self.height = height
            self.x = x
            self.y = y
            self.app = app
            self.maximize = maximize
            self.minimize = minimize
        }
    }

    public struct SwipeParameters: Codable, Sendable {
        public let direction: String
        public let distance: Double?
        public let duration: Double?
        public let fromX: Double?
        public let fromY: Double?

        public init(
            direction: String,
            distance: Double? = nil,
            duration: Double? = nil,
            fromX: Double? = nil,
            fromY: Double? = nil)
        {
            self.direction = direction
            self.distance = distance
            self.duration = duration
            self.fromX = fromX
            self.fromY = fromY
        }
    }

    public struct DragParameters: Codable, Sendable {
        public let fromX: Double
        public let fromY: Double
        public let toX: Double
        public let toY: Double
        public let duration: Double?
        public let modifiers: [String]?

        public init(
            fromX: Double,
            fromY: Double,
            toX: Double,
            toY: Double,
            duration: Double? = nil,
            modifiers: [String]? = nil)
        {
            self.fromX = fromX
            self.fromY = fromY
            self.toX = toX
            self.toY = toY
            self.duration = duration
            self.modifiers = modifiers
        }
    }

    public struct SleepParameters: Codable, Sendable {
        public let duration: Double

        public init(duration: Double) {
            self.duration = duration
        }
    }

    public struct DockParameters: Codable, Sendable {
        public let action: String
        public let item: String?
        public let path: String?

        public init(action: String, item: String? = nil, path: String? = nil) {
            self.action = action
            self.item = item
            self.path = path
        }
    }
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

    // MARK: - Output Types

    public struct ScreenshotOutput: Codable, Sendable {
        public let path: String
        public let width: Int
        public let height: Int
        public let fileSize: Int64?

        public init(path: String, width: Int, height: Int, fileSize: Int64? = nil) {
            self.path = path
            self.width = width
            self.height = height
            self.fileSize = fileSize
        }
    }

    public struct ElementOutput: Codable, Sendable {
        public let label: String?
        public let identifier: String?
        public let type: String
        public let frame: CGRect
        public let isEnabled: Bool
        public let isFocused: Bool

        public init(
            label: String?,
            identifier: String?,
            type: String,
            frame: CGRect,
            isEnabled: Bool,
            isFocused: Bool)
        {
            self.label = label
            self.identifier = identifier
            self.type = type
            self.frame = frame
            self.isEnabled = isEnabled
            self.isFocused = isFocused
        }
    }

    public struct WindowOutput: Codable, Sendable {
        public let title: String?
        public let app: String
        public let frame: CGRect
        public let isMinimized: Bool
        public let isMainWindow: Bool
        public let screenIndex: Int?
        public let screenName: String?

        public init(
            title: String?,
            app: String,
            frame: CGRect,
            isMinimized: Bool,
            isMainWindow: Bool,
            screenIndex: Int? = nil,
            screenName: String? = nil)
        {
            self.title = title
            self.app = app
            self.frame = frame
            self.isMinimized = isMinimized
            self.isMainWindow = isMainWindow
            self.screenIndex = screenIndex
            self.screenName = screenName
        }
    }
}
