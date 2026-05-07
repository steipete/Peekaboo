import Foundation

struct TypeCommandResult: Codable {
    let success: Bool
    let typedText: String?
    let keyPresses: Int
    let totalCharacters: Int
    let executionTime: TimeInterval
    let wordsPerMinute: Int?
    let profile: String
}
