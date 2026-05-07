import CoreGraphics
import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooBridge
import PeekabooFoundation

@MainActor
public final class RemoteWindowManagementService: WindowManagementServiceProtocol {
    private let client: PeekabooBridgeClient

    public init(client: PeekabooBridgeClient) {
        self.client = client
    }

    public func closeWindow(target: WindowTarget) async throws {
        try await self.client.closeWindow(target: target)
    }

    public func minimizeWindow(target: WindowTarget) async throws {
        try await self.client.minimizeWindow(target: target)
    }

    public func maximizeWindow(target: WindowTarget) async throws {
        try await self.client.maximizeWindow(target: target)
    }

    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        try await self.client.moveWindow(target: target, to: position)
    }

    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        try await self.client.resizeWindow(target: target, to: size)
    }

    public func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        try await self.client.setWindowBounds(target: target, bounds: bounds)
    }

    public func focusWindow(target: WindowTarget) async throws {
        try await self.client.focusWindow(target: target)
    }

    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        try await self.client.listWindows(target: target)
    }

    public func getFocusedWindow() async throws -> ServiceWindowInfo? {
        try await self.client.getFocusedWindow()
    }
}
