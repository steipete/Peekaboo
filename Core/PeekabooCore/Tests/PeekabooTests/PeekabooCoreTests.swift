import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Test
func configurationManager() async {
    let manager = ConfigurationManager.shared
    let providers = manager.getAIProviders()
    #expect(!providers.isEmpty)
}
