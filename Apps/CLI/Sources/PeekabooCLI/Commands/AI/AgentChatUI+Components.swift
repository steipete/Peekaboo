import TauTUI

/// Minimal loader component to keep chat rendering responsive without pulling in full spinner logic.
@MainActor
final class AgentChatLoader: Component {
    private var message: String

    init(tui: TUI, message: String) {
        self.message = message
    }

    func setMessage(_ message: String) {
        self.message = message
    }

    func stop() {}

    func render(width: Int) -> [String] {
        ["\(self.message)"]
    }
}

@MainActor
final class AgentChatInput: Component {
    private let editor = Editor()

    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onInterrupt: (() -> Void)?
    var onQueueWhileLocked: (() -> Void)?

    var isLocked: Bool = false {
        didSet {
            if !self.isLocked {
                self.editor.disableSubmit = false
            }
        }
    }

    init() {
        self.editor.onSubmit = { [weak self] value in
            self?.onSubmit?(value)
        }
    }

    func render(width: Int) -> [String] {
        self.editor.render(width: width)
    }

    func handle(input: TerminalInput) {
        switch input {
        case let .key(.character(char), modifiers):
            if modifiers.contains(.control) {
                let lower = String(char).lowercased()
                if lower == "c" || lower == "d" {
                    self.onInterrupt?()
                    return
                }
            }
        case .key(.escape, _):
            if self.isLocked {
                self.onCancel?()
                return
            }
        case .key(.end, _):
            if self.isLocked {
                // End lets a user keep typing while the current run owns normal submit.
                self.onQueueWhileLocked?()
                return
            }
        default:
            break
        }

        self.editor.handle(input: input)
    }

    func clear() {
        self.editor.setText("")
    }

    func currentText() -> String {
        self.editor.getText()
    }
}
