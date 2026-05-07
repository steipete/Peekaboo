import Foundation

extension ProcessCommandParameters {
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
}
