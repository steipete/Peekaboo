import Foundation
import Tachikoma

// MARK: - Completion Tools

/// Tools for task completion and status reporting
@available(macOS 14.0, *)
public enum CompletionTools {



}

// MARK: - Agent Tools Extension

@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the done tool for marking tasks as complete
    func createDoneTool() -> Tachikoma.AgentTool {
        Tachikoma.AgentTool(
            name: "done",
            description: "Mark the task as completed with a summary of what was accomplished",
            parameters: Tachikoma.AgentToolParameters(
                properties: [
                    Tachikoma.AgentToolParameterProperty(
                        name: "summary",
                        type: .string,
                        description: "Summary of what was accomplished"),
                ],
                required: ["summary"]),
            execute: { [services] params in
                guard let summary = params.optionalStringValue("summary") else {
                    throw PeekabooError.invalidInput("Summary parameter is required")
                }
                return .string("✅ Task completed: \(summary)")
            })
    }

    /// Create the need info tool for requesting more information
    func createNeedInfoTool() -> Tachikoma.AgentTool {
        Tachikoma.AgentTool(
            name: "need_info",
            description: "Request additional information from the user when the task is unclear or missing details",
            parameters: Tachikoma.AgentToolParameters(
                properties: [
                    Tachikoma.AgentToolParameterProperty(
                        name: "question",
                        type: .string,
                        description: "The question to ask the user"),
                    Tachikoma.AgentToolParameterProperty(
                        name: "context",
                        type: .string,
                        description: "Additional context for the question"),
                ],
                required: ["question"]),
            execute: { [services] params in
                guard let question = params.optionalStringValue("question") else {
                    throw PeekabooError.invalidInput("Question parameter is required")
                }
                let context = params.optionalStringValue("context")

                var response = "❓ Need more information: \(question)"
                if let context {
                    response += "\n\nContext: \(context)"
                }

                return .string(response)
            })
    }
}
