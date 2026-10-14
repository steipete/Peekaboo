import Foundation
import Tachikoma
import Testing
@testable import PeekabooAgentRuntime

@MainActor
struct AgentToolCompletionPayloadTests {
    @Test(arguments: ["result", "error"])
    func `Completion text round trips JSON special characters`(key: String) throws {
        let message = "Path C:\\tools\\file, quote: \"hello\"\nNext line\u{0001}\u{0000}"
        let payload = PeekabooAgentService.toolCompletionTextPayload([key: message])
        let decoded = try JSONSerialization.jsonObject(with: Data(payload.utf8))

        #expect(try #require(decoded as? [String: String]) == [key: message])
    }

    @Test
    func `Unserializable tool result emits valid fallback JSON`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentToolCompletionPayloadTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let services = DesktopContextPolicyServices()
        let service = try PeekabooAgentService(
            services: services,
            defaultModel: .openai(.gpt55),
            sessionManager: AgentSessionManager(sessionDirectory: directory))
        let result = AnyAgentToolValue(object: [
            "message": .init(string: "Path C:\\tools\\file, quote: \"hello\"\nNext line\u{0001}"),
            "invalid": .init(double: .infinity),
        ])
        let json = try result.toJSON()
        #expect(!JSONSerialization.isValidJSONObject(json))

        let payload = service.toolResultPayload(from: result, toolName: "fixture")
        let decoded = try JSONSerialization.jsonObject(with: Data(payload.utf8))

        #expect(try #require(decoded as? [String: String]) == ["result": String(describing: result)])
        #expect(services.requestedServices.isEmpty)
    }
}
