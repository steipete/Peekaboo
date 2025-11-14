import Testing
@testable import PeekabooCore
@testable import PeekabooAutomation
@testable import PeekabooAgentRuntime
@testable import PeekabooVisualizer

@Test
func configurationManager() async {
    let manager = ConfigurationManager.shared
    let providers = manager.getAIProviders()
    #expect(!providers.isEmpty)
}
