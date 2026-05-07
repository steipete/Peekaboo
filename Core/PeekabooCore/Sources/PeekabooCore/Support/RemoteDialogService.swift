import CoreGraphics
import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooBridge
import PeekabooFoundation

@MainActor
public final class RemoteDialogService: DialogServiceProtocol {
    private let client: PeekabooBridgeClient

    public init(client: PeekabooBridgeClient) {
        self.client = client
    }

    public func findActiveDialog(windowTitle: String?, appName: String?) async throws -> DialogInfo {
        try await self.client.dialogFindActive(windowTitle: windowTitle, appName: appName)
    }

    public func clickButton(buttonText: String, windowTitle: String?, appName: String?) async throws
        -> DialogActionResult
    {
        try await self.client.dialogClickButton(buttonText: buttonText, windowTitle: windowTitle, appName: appName)
    }

    public func enterText(
        text: String,
        fieldIdentifier: String?,
        clearExisting: Bool,
        windowTitle: String?,
        appName: String?) async throws -> DialogActionResult
    {
        try await self.client.dialogEnterText(
            text: text,
            fieldIdentifier: fieldIdentifier,
            clearExisting: clearExisting,
            windowTitle: windowTitle,
            appName: appName)
    }

    public func handleFileDialog(
        path: String?,
        filename: String?,
        actionButton: String?,
        ensureExpanded: Bool,
        appName: String?) async throws
        -> DialogActionResult
    {
        try await self.client.dialogHandleFile(
            path: path,
            filename: filename,
            actionButton: actionButton,
            ensureExpanded: ensureExpanded,
            appName: appName)
    }

    public func dismissDialog(force: Bool, windowTitle: String?, appName: String?) async throws -> DialogActionResult {
        try await self.client.dialogDismiss(force: force, windowTitle: windowTitle, appName: appName)
    }

    public func listDialogElements(windowTitle: String?, appName: String?) async throws -> DialogElements {
        try await self.client.dialogListElements(windowTitle: windowTitle, appName: appName)
    }
}
