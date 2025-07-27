import Foundation

/// Special tools for signaling task completion
public enum CompletionTools {
    
    /// Creates a "done" tool that agents must call when they complete their task
    public static func createDoneTool<Context>() -> Tool<Context> {
        Tool(
            name: "task_completed",
            description: "Call this tool when you have completed all requested tasks. Include a summary of what was accomplished.",
            parameters: ToolParameters.object(
                properties: [
                    "summary": ParameterSchema.string(description: "Brief summary of what was accomplished"),
                    "success": ParameterSchema.boolean(description: "Whether all tasks were completed successfully"),
                    "next_steps": ParameterSchema.string(description: "Optional suggestions for follow-up actions")
                ],
                required: ["summary", "success"]
            ),
            execute: { input, _ in
                let summary: String = input.value(for: "summary") ?? ""
                let success: Bool = input.value(for: "success") ?? true
                let nextSteps: String? = input.value(for: "next_steps")
                
                var result: [String: Any] = [
                    "type": "task_completion",
                    "summary": summary,
                    "success": success
                ]
                
                if let next = nextSteps {
                    result["next_steps"] = next
                }
                
                return .dictionary(result)
            }
        )
    }
    
    /// Creates a "need_more_info" tool for when the agent needs clarification
    public static func createNeedInfoTool<Context>() -> Tool<Context> {
        Tool(
            name: "need_more_information",
            description: "Call this tool when you need additional information or clarification from the user to complete the task.",
            parameters: ToolParameters.object(
                properties: [
                    "question": ParameterSchema.string(description: "The specific question or clarification needed"),
                    "context": ParameterSchema.string(description: "Why this information is needed")
                ],
                required: ["question", "context"]
            ),
            execute: { input, _ in
                let question: String = input.value(for: "question") ?? ""
                let context: String = input.value(for: "context") ?? ""
                
                return .dictionary([
                    "type": "need_info",
                    "question": question,
                    "context": context
                ])
            }
        )
    }
}