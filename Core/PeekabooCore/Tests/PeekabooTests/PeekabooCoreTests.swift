import Testing
@testable import PeekabooCore

@Test
func configurationManager() async {
    let manager = ConfigurationManager.shared
    let providers = manager.getAIProviders()
    #expect(!providers.isEmpty)
}
