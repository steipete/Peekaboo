import Foundation
import PeekabooCore

// MARK: - Type Aliases for PeekabooCore Types

typealias Assistant = PeekabooCore.Assistant
typealias Thread = PeekabooCore.Thread
typealias Run = PeekabooCore.Run
typealias RequiredAction = PeekabooCore.RequiredAction
typealias SubmitToolOutputs = PeekabooCore.SubmitToolOutputs
typealias OpenAIToolCall = PeekabooCore.ToolCall
typealias FunctionCall = PeekabooCore.FunctionCall
typealias Message = PeekabooCore.Message
typealias MessageContent = PeekabooCore.MessageContent
typealias TextContent = PeekabooCore.TextContent
typealias MessageList = PeekabooCore.MessageList
typealias Tool = PeekabooCore.Tool
typealias ToolFunction = PeekabooCore.ToolFunction
typealias FunctionParameters = PeekabooCore.FunctionParameters
typealias Property = PeekabooCore.Property
typealias OpenAIError = PeekabooCore.OpenAIError
typealias AssistantRequest = PeekabooCore.AssistantRequest
typealias AgentError = PeekabooCore.AgentError
// OpenAIAgentResult doesn't exist in PeekabooCore - use AgentResult instead
typealias ToolExecutor = PeekabooCore.ToolExecutor
