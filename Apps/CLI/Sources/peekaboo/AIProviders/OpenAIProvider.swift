import Foundation
import PeekabooCore

/// Local wrapper for OpenAIProvider to maintain CLI-specific behavior
class OpenAIProvider: PeekabooCore.OpenAIProvider {
    // CLI-specific configuration that uses local ConfigurationManager
    override public var apiKey: String? {
        ConfigurationManager.shared.getOpenAIAPIKey()
    }
}
