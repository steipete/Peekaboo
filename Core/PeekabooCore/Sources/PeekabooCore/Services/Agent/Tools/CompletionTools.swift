import Foundation

// MARK: - Completion Tools

/// Tools for task completion and status reporting
@available(macOS 14.0, *)
public enum CompletionTools {
    /// Create the done tool for marking tasks as complete
    public static func createDoneTool<Services>() -> Tool<Services> {
        Tool(
            name: "done",
            description: "Mark the task as completed with a summary of what was accomplished",
            parameters: ToolParameters.object(
                properties: [
                    "summary": ParameterSchema.string(
                        description: "Brief summary of what was accomplished"
                    )
                ],
                required: ["summary"]
            ),
            execute: { params, _ in
                let summary = try params.string("summary") ?? "Task completed"
                return .success("✅ Task completed: \(summary)")
            }
        )
    }
    
    /// Create the need info tool for requesting more information
    public static func createNeedInfoTool<Services>() -> Tool<Services> {
        Tool(
            name: "need_info",
            description: "Request additional information from the user when the task is unclear or missing details",
            parameters: ToolParameters.object(
                properties: [
                    "question": ParameterSchema.string(
                        description: "The specific question or information needed from the user"
                    ),
                    "context": ParameterSchema.string(
                        description: "Additional context about why this information is needed"
                    )
                ],
                required: ["question"]
            ),
            execute: { params, _ in
                let question = try params.string("question") ?? "Additional information needed"
                let context = params.string("context", default: nil)
                
                var response = "❓ Need more information: \(question)"
                if let context {
                    response += "\n\nContext: \(context)"
                }
                
                return .success(response)
            }
        )
    }
}