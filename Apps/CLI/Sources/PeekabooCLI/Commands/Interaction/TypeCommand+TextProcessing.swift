import PeekabooFoundation

extension TypeCommand {
    /// Process text with escape sequences like \n, \t, etc.
    static func processTextWithEscapes(_ text: String) -> [TypeAction] {
        var actions: [TypeAction] = []
        var currentText = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if character == "\\" && text.index(after: index) < text.endIndex {
                let nextCharacter = text[text.index(after: index)]

                switch nextCharacter {
                case "n":
                    Self.flush(&currentText, into: &actions)
                    actions.append(.key(.return))
                    index = text.index(after: index)

                case "t":
                    Self.flush(&currentText, into: &actions)
                    actions.append(.key(.tab))
                    index = text.index(after: index)

                case "b":
                    Self.flush(&currentText, into: &actions)
                    actions.append(.key(.delete))
                    index = text.index(after: index)

                case "e":
                    Self.flush(&currentText, into: &actions)
                    actions.append(.key(.escape))
                    index = text.index(after: index)

                case "\\":
                    currentText.append("\\")
                    index = text.index(after: index)

                default:
                    currentText.append(character)
                }
            } else {
                currentText.append(character)
            }

            index = text.index(after: index)
        }

        Self.flush(&currentText, into: &actions)
        return actions
    }

    private static func flush(_ text: inout String, into actions: inout [TypeAction]) {
        guard !text.isEmpty else { return }
        actions.append(.text(text))
        text = ""
    }
}
