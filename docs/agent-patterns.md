---
summary: 'Review Agent Patterns Documentation guidance'
read_when:
  - 'planning work related to agent patterns documentation'
  - 'debugging or extending features described here'
---

# Agent Patterns Documentation

This document describes the advanced agent patterns implemented in Peekaboo, inspired by the OpenAI SDK.

## Table of Contents
1. [Explicit Task Completion](#explicit-task-completion)
2. [Tool Approval Mechanism](#tool-approval-mechanism)
3. [Lifecycle Hooks](#lifecycle-hooks)
4. [Best Practices](#best-practices)

## Explicit Task Completion

### Problem
Previously, the agent would guess when a task was complete based on:
- Iteration count and content length
- Magic phrases like "task is done"
- Detecting "finishing" tools like `say`

This led to premature completion when agents were explaining their plans.

### Solution
Agents now must explicitly signal completion using dedicated tools:

#### `task_completed` Tool
```swift
// Agent must call this when done
{
  "name": "task_completed",
  "arguments": {
    "summary": "Converted ODS file to Markdown and sent email with poem",
    "success": true,
    "next_steps": "Consider installing pandoc for faster conversions"
  }
}
```

#### `need_more_information` Tool
```swift
// Agent calls this when blocked
{
  "name": "need_more_information", 
  "arguments": {
    "question": "Which email account should I use to send the message?",
    "context": "Multiple email accounts are configured"
  }
}
```

### Implementation
1. Tools defined in `CompletionTools.swift`
2. System prompt updated to require these tools
3. AgentRunner checks for `task_completed` tool call
4. CLI displays completion summary prominently

## Tool Approval Mechanism

### Configuration
```swift
let config = ToolApprovalConfig(
    requiresApproval: ["shell", "delete_file"],
    alwaysApproved: ["screenshot", "list_apps"],
    alwaysRejected: ["rm -rf /"],
    approvalHandler: InteractiveApprovalHandler()
)
```

### Interactive Approval
When a tool requires approval:
```
⚠️  Tool Approval Required
Tool: shell
Arguments: {"command": "rm important-file.txt"}
Context: User requested file deletion

Approve? [y/n/always/never]: 
```

### Approval Results
- `approved`: Allow this execution
- `rejected`: Block this execution
- `approvedAlways`: Allow all future calls to this tool
- `rejectedAlways`: Block all future calls to this tool

## Lifecycle Hooks

### Events
```swift
public enum AgentLifecycleEvent {
    case agentStarted(agent: String, context: String?)
    case agentEnded(agent: String, output: String?)
    case toolStarted(name: String, arguments: String)
    case toolEnded(name: String, result: String, success: Bool)
    case iterationStarted(number: Int)
    case iterationCompleted(number: Int)
    case errorOccurred(error: Error, context: String?)
}
```

### Handlers

#### Console Logger
```swift
let consoleHandler = ConsoleLifecycleHandler(
    verbose: true,
    includeTimestamps: true
)
```

Output:
```
[14:23:45.123] 🚀 Agent 'Peekaboo Assistant' started
[14:23:45.234] 🔧 Tool 'screenshot' started
[14:23:45.567] 🔧 Tool 'screenshot' ✓
[14:23:46.789] ✅ Agent 'Peekaboo Assistant' completed
```

#### Metrics Collector
```swift
let metricsHandler = MetricsLifecycleHandler()

// After execution
let metrics = await metricsHandler.getMetrics()
print("Total tool calls: \(metrics.totalToolCalls)")
print("Average execution time: \(metrics.executionTimes.average)")
```

### Custom Handlers
```swift
actor CustomHandler: AgentLifecycleHandler {
    func handle(event: AgentLifecycleEvent) async {
        switch event {
        case .toolStarted(let name, _) where name == "shell":
            // Log shell commands to audit trail
            await AuditLog.record("Shell command executed")
        default:
            break
        }
    }
}
```

## Best Practices

### 1. Always Use Completion Tools
- Don't rely on heuristics
- Agents must explicitly call `task_completed`
- Handle `need_more_information` gracefully

### 2. Configure Tool Approvals
- Require approval for destructive operations
- Auto-approve read-only operations
- Let users set permanent preferences

### 3. Add Lifecycle Handlers
- Use console handler for debugging
- Add metrics handler for performance monitoring
- Create custom handlers for audit trails

### 4. Error Handling
- Lifecycle events include error cases
- Tool errors don't stop execution
- Approval rejections are handled gracefully

## Migration Guide

### Updating Existing Agents
1. Add completion tools to your tool list
2. Update system prompt to mention completion requirement
3. Test that agents call `task_completed`

### Adding Approvals
1. Create `ToolApprovalConfig`
2. Pass to agent during creation
3. Implement custom approval handler if needed

### Adding Lifecycle Tracking
1. Create handlers for your needs
2. Add to `LifecycleManager`
3. Events will automatically flow

## Future Enhancements

1. **Agent Handoffs**: Transfer control between specialized agents
2. **Guardrails**: Input/output validation with tripwires  
3. **Structured Output**: Type-safe outputs with schemas
4. **Persistence**: Save and restore approval preferences
5. **Web UI**: Visual approval interface