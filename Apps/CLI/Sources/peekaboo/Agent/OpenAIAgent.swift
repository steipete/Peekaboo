import Foundation

public struct OpenAIAgent {
    public struct AgentResult: Codable {
        public struct Step: Codable {
            public let description: String
            public let command: String
            public let output: String
            public let screenshot: String?
            
            public init(description: String, command: String, output: String, screenshot: String? = nil) {
                self.description = description
                self.command = command
                self.output = output
                self.screenshot = screenshot
            }
        }
        
        public let steps: [Step]
        public let summary: String
        public let success: Bool
        
        public init(steps: [Step], summary: String, success: Bool) {
            self.steps = steps
            self.summary = summary
            self.success = success
        }
    }
}