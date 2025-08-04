import Foundation
import Tachikoma

// MARK: - Completion Tools

/// Tools for task completion and status reporting
@available(macOS 14.0, *)
public enum CompletionTools {
    /// Create the done tool for marking tasks as complete - SimpleTool version
    public static func createDoneSimpleTool() -> SimpleTool {
        SimpleTool(
            name: "done",
            description: "Mark the task as completed with a summary of what was accomplished",
            parameters: ToolParameters(
                properties: [
                    "summary": ToolParameterProperty(
                        name: "summary",
                        type: .string,
                        description: "Summary of what was accomplished"),
                ],
                required: ["summary"]),
            execute: { args in
                let summary = try args.stringValue("summary")
                return .string("✅ Task completed: \(summary)")
            })
    }

    /// Create the need info tool for requesting more information - SimpleTool version
    public static func createNeedInfoSimpleTool() -> SimpleTool {
        SimpleTool(
            name: "need_info",
            description: "Request additional information from the user when the task is unclear or missing details",
            parameters: ToolParameters(
                properties: [
                    "question": ToolParameterProperty(
                        name: "question",
                        type: .string,
                        description: "The question to ask the user"),
                    "context": ToolParameterProperty(
                        name: "context",
                        type: .string,
                        description: "Additional context for the question"),
                ],
                required: ["question"]),
            execute: { args in
                let question = try args.stringValue("question")
                let context = (try? args.stringValue("context")) ?? nil

                var response = "❓ Need more information: \(question)"
                if let context {
                    response += "\n\nContext: \(context)"
                }

                return .string(response)
            })
    }

    /// Create the done tool for marking tasks as complete (legacy Tool<Context> version)
    public static func createDoneTool<Services>() -> Tool<Services> {
        Tool(
            name: "done",
            description: "Mark the task as completed with a summary of what was accomplished"
        ) { params, _ in
            let summary = try params.stringValue("summary")
            return ToolOutput.success("✅ Task completed: \(summary)")
        }
    }

    /// Create the need info tool for requesting more information (legacy Tool<Context> version)
    public static func createNeedInfoTool<Services>() -> Tool<Services> {
        Tool(
            name: "need_info",
            description: "Request additional information from the user when the task is unclear or missing details"
        ) { params, _ in
                let question = try params.stringValue("question")
                let context = params.stringValue("context", default: nil)

                var response = "❓ Need more information: \(question)"
                if let context {
                    response += "\n\nContext: \(context)"
                }

                return ToolOutput.success(response)
        }
    }
}
