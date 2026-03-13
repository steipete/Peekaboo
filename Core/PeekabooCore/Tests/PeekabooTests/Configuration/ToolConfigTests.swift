import Foundation
import PeekabooAutomation
import Testing

struct ToolConfigTests {
    @Test
    func `Codable round-trip for tool lists`() throws {
        let tools = Configuration.ToolConfig(allow: ["see", "click"], deny: ["shell"])
        let config = Configuration(tools: tools)

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Configuration.self, from: data)

        #expect(decoded.tools?.allow == ["see", "click"])
        #expect(decoded.tools?.deny == ["shell"])
    }
}
