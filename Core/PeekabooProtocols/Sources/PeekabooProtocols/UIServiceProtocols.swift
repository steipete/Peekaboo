//
//  UIServiceProtocols.swift
//  PeekabooProtocols
//

import CoreGraphics
import Foundation
import PeekabooFoundation

// MARK: - UI Service Protocols

/// Protocol for screen capture service operations
public protocol ScreenCaptureServiceProtocol: Sendable {
    func captureScreen(screen: Int?, rect: CGRect?) async throws -> Data
    func captureWindow(windowID: Int) async throws -> Data
    func captureApplication(appName: String) async throws -> Data
    func listWindows() async throws -> [WindowInfo]
}

public struct WindowInfo: Sendable {
    public let id: Int
    public let title: String
    public let appName: String
    public let bounds: CGRect

    public init(id: Int, title: String, appName: String, bounds: CGRect) {
        self.id = id
        self.title = title
        self.appName = appName
        self.bounds = bounds
    }
}

/// Protocol for screen service operations
public protocol ScreenServiceProtocol: Sendable {
    func getScreenCount() async -> Int
    func getMainScreen() async -> ScreenInfo?
    func getAllScreens() async -> [ScreenInfo]
    func getScreenAt(point: CGPoint) async -> ScreenInfo?
}

public struct ScreenInfo: Sendable {
    public let id: Int
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let scaleFactor: CGFloat

    public init(id: Int, frame: CGRect, visibleFrame: CGRect, scaleFactor: CGFloat) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scaleFactor = scaleFactor
    }
}

/// Protocol for session manager operations
@MainActor
public protocol SessionManagerProtocol: Sendable {
    func createSession(id: String?) async -> String
    func getSession(id: String) async -> SessionData?
    func updateSession(id: String, data: SessionData) async
    func deleteSession(id: String) async
    func listSessions() async -> [String]
    func getDetectionResult(sessionId: String) async throws -> DetectionResult
    func storeDetectionResult(_ result: DetectionResult, sessionId: String) async
}

public struct SessionData: Sendable {
    public let id: String
    public let createdAt: Date
    public let metadata: [String: String]

    public init(id: String, createdAt: Date, metadata: [String: String] = [:]) {
        self.id = id
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

public struct DetectionResult: Sendable {
    public let elements: ElementCollection
    public let timestamp: Date

    public init(elements: ElementCollection, timestamp: Date) {
        self.elements = elements
        self.timestamp = timestamp
    }
}

public struct ElementCollection: Sendable {
    public let all: [DetectedElement]

    public init(all: [DetectedElement]) {
        self.all = all
    }

    public func findById(_ id: String) -> DetectedElement? {
        self.all.first { $0.id == id }
    }
}

public struct DetectedElement: Sendable, Codable {
    public let id: String
    public let type: ElementType
    public let bounds: CGRect
    public let label: String?
    public let value: String?
    public let isEnabled: Bool

    public init(
        id: String,
        type: ElementType,
        bounds: CGRect,
        label: String? = nil,
        value: String? = nil,
        isEnabled: Bool = true)
    {
        self.id = id
        self.type = type
        self.bounds = bounds
        self.label = label
        self.value = value
        self.isEnabled = isEnabled
    }
}

/// Protocol for UI automation service operations
public protocol UIAutomationServiceProtocol: Sendable {
    func click(at point: CGPoint, clickType: ClickType) async throws
    func type(text: String) async throws
    func scroll(direction: ScrollDirection, amount: Int) async throws
    func swipe(from: CGPoint, to: CGPoint, duration: TimeInterval) async throws
    func findElement(matching query: String) async throws -> DetectedElement?
    func getElements() async throws -> [DetectedElement]
}

/// Protocol for window management service operations
public protocol WindowManagementServiceProtocol: Sendable {
    func listWindows() async throws -> [WindowInfo]
    func focusWindow(id: Int) async throws
    func closeWindow(id: Int) async throws
    func minimizeWindow(id: Int) async throws
    func maximizeWindow(id: Int) async throws
    func moveWindow(id: Int, to point: CGPoint) async throws
    func resizeWindow(id: Int, to size: CGSize) async throws
    func getWindowInfo(id: Int) async throws -> WindowInfo?
}
