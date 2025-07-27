import Foundation

/// Tool approval configuration and handling
public struct ToolApprovalConfig {
    /// Tools that require approval before execution
    public let requiresApproval: Set<String>
    
    /// Tools that are always approved
    public let alwaysApproved: Set<String>
    
    /// Tools that are always rejected
    public let alwaysRejected: Set<String>
    
    /// Default approval handler
    public let approvalHandler: ApprovalHandler?
    
    public init(
        requiresApproval: Set<String> = [],
        alwaysApproved: Set<String> = [],
        alwaysRejected: Set<String> = [],
        approvalHandler: ApprovalHandler? = nil
    ) {
        self.requiresApproval = requiresApproval
        self.alwaysApproved = alwaysApproved
        self.alwaysRejected = alwaysRejected
        self.approvalHandler = approvalHandler
    }
}

/// Handler for tool approval requests
public protocol ApprovalHandler: Sendable {
    func requestApproval(
        toolName: String,
        arguments: String,
        context: String?
    ) async -> ApprovalResult
}

/// Result of an approval request
public enum ApprovalResult {
    case approved
    case rejected(reason: String?)
    case approvedAlways  // Approve this and all future calls
    case rejectedAlways  // Reject this and all future calls
}

/// Tool approval item for tracking
public struct ToolApprovalItem {
    public let id: String
    public let toolName: String
    public let arguments: String
    public let timestamp: Date
    public var status: ApprovalStatus
    
    public init(
        id: String = UUID().uuidString,
        toolName: String,
        arguments: String,
        timestamp: Date = Date(),
        status: ApprovalStatus = .pending
    ) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.timestamp = timestamp
        self.status = status
    }
}

/// Status of a tool approval
public enum ApprovalStatus {
    case pending
    case approved
    case rejected(reason: String?)
}

/// Manager for tool approvals during agent execution
public actor ToolApprovalManager {
    private var approvals: [String: ApprovalStatus] = [:]
    private var config: ToolApprovalConfig
    
    public init(config: ToolApprovalConfig = ToolApprovalConfig()) {
        self.config = config
    }
    
    /// Check if a tool requires approval
    public func requiresApproval(toolName: String) -> Bool {
        // Check if always rejected
        if config.alwaysRejected.contains(toolName) {
            return true
        }
        
        // Check if always approved
        if config.alwaysApproved.contains(toolName) {
            return false
        }
        
        // Check if in requires approval list
        return config.requiresApproval.contains(toolName)
    }
    
    /// Request approval for a tool call
    public func requestApproval(
        toolName: String,
        arguments: String,
        context: String? = nil
    ) async -> ApprovalResult {
        // Check cached approvals
        let key = "\(toolName):\(arguments)"
        if let cached = approvals[key] {
            switch cached {
            case .approved:
                return .approved
            case .rejected(let reason):
                return .rejected(reason: reason)
            case .pending:
                break
            }
        }
        
        // Check config rules
        if config.alwaysRejected.contains(toolName) {
            return .rejected(reason: "Tool is in always-rejected list")
        }
        
        if config.alwaysApproved.contains(toolName) {
            return .approved
        }
        
        // Request approval from handler
        guard let handler = config.approvalHandler else {
            // Default to approved if no handler
            return .approved
        }
        
        let result = await handler.requestApproval(
            toolName: toolName,
            arguments: arguments,
            context: context
        )
        
        // Cache result if permanent
        switch result {
        case .approvedAlways:
            approvals[key] = .approved
        case .rejectedAlways:
            approvals[key] = .rejected(reason: nil)
        default:
            break
        }
        
        return result
    }
    
    /// Update configuration
    public func updateConfig(_ config: ToolApprovalConfig) {
        self.config = config
    }
    
    /// Clear all cached approvals
    public func clearCache() {
        approvals.removeAll()
    }
}

/// Interactive approval handler for CLI
public struct InteractiveApprovalHandler: ApprovalHandler {
    public init() {}
    
    public func requestApproval(
        toolName: String,
        arguments: String,
        context: String?
    ) async -> ApprovalResult {
        print("\n⚠️  Tool Approval Required")
        print("Tool: \(toolName)")
        print("Arguments: \(arguments)")
        if let context = context {
            print("Context: \(context)")
        }
        print("\nApprove? [y/n/always/never]: ", terminator: "")
        
        guard let response = readLine()?.lowercased() else {
            return .rejected(reason: "No response provided")
        }
        
        switch response {
        case "y", "yes":
            return .approved
        case "n", "no":
            return .rejected(reason: "User rejected")
        case "always":
            return .approvedAlways
        case "never":
            return .rejectedAlways
        default:
            return .rejected(reason: "Invalid response")
        }
    }
}