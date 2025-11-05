//
//  ObservableProtocols.swift
//  PeekabooProtocols
//

import Foundation
import PeekabooFoundation

// MARK: - Observable Service Protocols

/// Protocol for observable permissions service
public protocol ObservablePermissionsServiceProtocol: AnyObject {
    var screenRecordingStatus: PermissionState { get }
    var accessibilityStatus: PermissionState { get }
    var appleScriptStatus: PermissionState { get }
    var hasAllPermissions: Bool { get }

    func checkPermissions()
    func requestPermissions() async
}

public enum PermissionState: String, Sendable {
    case notDetermined
    case denied
    case authorized
}

// MARK: - Tool Protocols

/// Protocol for tool formatters
public protocol ToolFormatterProtocol {
    func format(output: ToolOutput) -> String
    func supports(tool: String) -> Bool
}

public struct ToolOutput: Sendable {
    public let tool: String
    public let result: String
    public let metadata: [String: String] // Changed from Any to String for Sendable conformance

    public init(tool: String, result: String, metadata: [String: String] = [:]) {
        self.tool = tool
        self.result = result
        self.metadata = metadata
    }
}

// MARK: - Visualization Protocols

/// Protocol for visualizer XPC service
public protocol VisualizerXPCProtocol {
    func showScreenshotFlash(in rect: CGRect, showGhost: Bool, reply: @escaping (Bool) -> Void)
    func showClickFeedback(at point: CGPoint, type: String, reply: @escaping (Bool) -> Void)
    func showTypingFeedback(keys: [String], duration: TimeInterval, reply: @escaping (Bool) -> Void)
    func showScrollFeedback(at point: CGPoint, direction: String, amount: Int, reply: @escaping (Bool) -> Void)
    func showMouseMovement(from: CGPoint, to: CGPoint, duration: TimeInterval, reply: @escaping (Bool) -> Void)
    func showSwipePath(from: CGPoint, to: CGPoint, duration: TimeInterval, reply: @escaping (Bool) -> Void)
    func showHotkeyPress(keys: [String], duration: TimeInterval, reply: @escaping (Bool) -> Void)
    func showMenuNavigation(menuPath: [String], duration: TimeInterval, reply: @escaping (Bool) -> Void)
    func showDialogInteraction(action: String, duration: TimeInterval, reply: @escaping (Bool) -> Void)
    func showAnnotations(elements: [[String: String]], duration: TimeInterval, reply: @escaping (Bool) -> Void)
    func hideAllAnimations(reply: @escaping (Bool) -> Void)
}

// MARK: - Configuration Protocols

/// Protocol for configuration providers
public protocol ConfigurationProviderProtocol {
    func getValue(for key: String) -> String?
    func setValue(_ value: String?, for key: String)
    func getAllValues() -> [String: String]
    func reset()
}

// MARK: - Focus Options Protocol

public protocol FocusOptionsProtocol {
    var raiseWindow: Bool { get }
    var activateApp: Bool { get }
    var waitForWindow: Bool { get }
    var timeout: TimeInterval { get }
}

// MARK: - Storage Protocols

/// Protocol for conversation session storage
public protocol ConversationSessionStorageProtocol {
    func save(_ session: ConversationSession) async throws
    func load(id: String) async throws -> ConversationSession?
    func delete(id: String) async throws
    func listAll() async throws -> [ConversationSession]
}

public struct ConversationSession: Sendable {
    public let id: String
    public let startedAt: Date
    public let messages: [ConversationMessage]

    public init(id: String, startedAt: Date, messages: [ConversationMessage] = []) {
        self.id = id
        self.startedAt = startedAt
        self.messages = messages
    }
}

public struct ConversationMessage: Sendable {
    public let role: String
    public let content: String
    public let timestamp: Date

    public init(role: String, content: String, timestamp: Date) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
