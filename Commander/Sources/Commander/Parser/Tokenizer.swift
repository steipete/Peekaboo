import Foundation

enum Token: Equatable, Sendable {
    case option(name: String)
    case flag(name: String)
    case argument(String)
    case terminator
}

enum CommandLineTokenizer {
    static func tokenize(_ argv: [String]) -> [Token] {
        var result: [Token] = []
        var iterator = argv.makeIterator()
        while let segment = iterator.next() {
            if segment == "--" {
                result.append(.terminator)
                result.append(contentsOf: iterator.map { .argument($0) })
                break
            } else if segment.hasPrefix("--") {
                let name = String(segment.dropFirst(2))
                result.append(.option(name: name))
            } else if segment.hasPrefix("-"), segment.count > 1 {
                let body = segment.dropFirst()
                if body.count == 1 {
                    result.append(.option(name: String(body)))
                } else {
                    for char in body {
                        result.append(.flag(name: String(char)))
                    }
                }
            } else {
                result.append(.argument(segment))
            }
        }
        return result
    }
}
