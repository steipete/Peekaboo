import Foundation
import TachikomaCore

// MARK: - Completion Tools

/// Tools for task completion and status reporting
@available(macOS 14.0, *)
public enum CompletionTools {
    /// Create the done tool for marking tasks as complete
    public static func createDoneTool<Services>() -> Tool<Services> {
        Tool(
            name: "done",
            description: "Mark the task as completed with a summary of what was accomplished",
            execute: { params, _ in
                let summary = try params.stringValue("summary")
                return ToolOutput.success("✅ Task completed: \(summary)")
            })
    }

    /// Create the need info tool for requesting more information
    public static func createNeedInfoTool<Services>() -> Tool<Services> {
        Tool(
            name: "need_info",
            description: "Request additional information from the user when the task is unclear or missing details",
            execute: { params, _ in
                let question = try params.stringValue("question")
                let context = params.stringValue("context", default: nil)

                var response = "❓ Need more information: \(question)"
                if let context {
                    response += "\n\nContext: \(context)"
                }

                return ToolOutput.success(response)
            })
    }
}
