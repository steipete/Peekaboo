import Foundation
import PeekabooCore

/// Local wrapper for OllamaProvider to maintain CLI-specific behavior
class OllamaProvider: PeekabooCore.OllamaProvider {
    // CLI-specific configuration that uses local ConfigurationManager
    override public var baseURL: URL {
        let baseURLString = ConfigurationManager.shared.getOllamaBaseURL()
        return URL(string: baseURLString) ?? URL(string: "http://localhost:11434")!
    }
}
