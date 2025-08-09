//
//  ServiceProtocols.swift
//  PeekabooProtocols
//

import Foundation
import PeekabooFoundation

// MARK: - Core Service Protocols

/// Protocol for agent service operations
public protocol AgentServiceProtocol: Sendable {
    func processMessage(_ message: String, sessionId: String?) async throws -> String
    func cancelCurrentOperation() async
    func clearHistory() async
    func getSessionHistory(_ sessionId: String) async -> [String]
}

/// Protocol for application service operations
public protocol ApplicationServiceProtocol: Sendable {
    func listApplications() async throws -> [String]
    func focusApplication(name: String) async throws
    func quitApplication(name: String) async throws
    func hideApplication(name: String) async throws
    func unhideApplication(name: String) async throws
    func getActiveApplication() async throws -> String?
    func getApplicationWindows(appName: String) async throws -> [String]
}

/// Protocol for dialog service operations
public protocol DialogServiceProtocol: Sendable {
    func findDialog(timeout: TimeInterval) async throws -> String?
    func fillDialog(text: String, fieldIndex: Int?) async throws
    func clickDialogButton(buttonText: String) async throws
    func dismissDialog() async throws
}

/// Protocol for dock service operations
public protocol DockServiceProtocol: Sendable {
    func listDockItems() async throws -> [String]
    func clickDockItem(name: String) async throws
    func rightClickDockItem(name: String) async throws
    func isDockItemRunning(name: String) async throws -> Bool
}

/// Protocol for file service operations
public protocol FileServiceProtocol: Sendable {
    func readFile(at path: String) async throws -> Data
    func writeFile(data: Data, to path: String) async throws
    func deleteFile(at path: String) async throws
    func fileExists(at path: String) async -> Bool
    func createDirectory(at path: String) async throws
    func listDirectory(at path: String) async throws -> [String]
}

/// Protocol for logging service operations
public protocol LoggingServiceProtocol: Sendable {
    func log(_ message: String, level: LogLevel)
    func logError(_ error: Error, context: String?)
    func flush() async
}

public enum LogLevel: String, Sendable {
    case debug, info, warning, error, critical
}

/// Protocol for menu service operations
public protocol MenuServiceProtocol: Sendable {
    func clickMenuItem(path: [String], appName: String?) async throws
    func getMenuItems(appName: String?) async throws -> [[String]]
    func isMenuItemEnabled(path: [String], appName: String?) async throws -> Bool
}

/// Protocol for process service operations
public protocol ProcessServiceProtocol: Sendable {
    func runCommand(_ command: String, arguments: [String], environment: [String: String]?) async throws -> ProcessOutput
    func runShellCommand(_ command: String) async throws -> ProcessOutput
    func killProcess(pid: Int32) async throws
    func findProcess(name: String) async throws -> Int32?
}

public struct ProcessOutput: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    
    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}