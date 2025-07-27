import Foundation
import CoreGraphics
import AXorcist

// MARK: - Dialog Tools

/// Dialog interaction tools for clicking buttons and entering text in dialogs
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the dialog click tool
    func createDialogClickTool() -> Tool<PeekabooServices> {
        createTool(
            name: "dialog_click",
            description: "Click a button in a dialog, sheet, or alert",
            parameters: .object(
                properties: [
                    "button": ParameterSchema.string(description: "Button label to click (e.g., 'OK', 'Cancel', 'Save')"),
                    "app": ParameterSchema.string(description: "Optional: Application name")
                ],
                required: ["button"]
            ),
            handler: { params, context in
                let buttonLabel = try params.string("button")
                let appName = params.string("app", default: nil)
                
                _ = try await context.dialogs.clickButton(
                    buttonText: buttonLabel,
                    windowTitle: appName
                )
                
                return .success(
                    "Clicked '\(buttonLabel)' button in dialog",
                    metadata: [
                        "button": buttonLabel,
                        "app": appName ?? "current app"
                    ]
                )
            }
        )
    }
    
    /// Create the dialog input tool
    func createDialogInputTool() -> Tool<PeekabooServices> {
        createTool(
            name: "dialog_input",
            description: "Enter text into a field in a dialog or sheet",
            parameters: .object(
                properties: [
                    "text": ParameterSchema.string(description: "Text to enter"),
                    "field": ParameterSchema.string(description: "Optional: Field label or placeholder text"),
                    "app": ParameterSchema.string(description: "Optional: Application name"),
                    "clear_first": ParameterSchema.boolean(description: "Clear the field before typing (default: true)")
                ],
                required: ["text"]
            ),
            handler: { params, context in
                let text = try params.string("text")
                let fieldLabel = params.string("field", default: nil)
                let appName = params.string("app", default: nil)
                let clearFirst = params.bool("clear_first", default: true)
                
                // For now, this is a simplified implementation
                // Field-specific targeting is not yet supported
                if fieldLabel != nil {
                    throw PeekabooError.serviceUnavailable("Field-specific text entry not yet implemented")
                }
                
                // Clear if requested
                if clearFirst {
                    try await context.automation.hotkey(keys: "cmd,a", holdDuration: 0)
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                    try await context.automation.hotkey(keys: "delete", holdDuration: 0)
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                }
                
                // Type the text
                try await context.automation.type(
                    text: text,
                    target: nil,
                    clearExisting: false,
                    typingDelay: 0,
                    sessionId: nil
                )
                
                var output = "Entered text in dialog"
                if let fieldLabel = fieldLabel {
                    output += " field '\(fieldLabel)'"
                }
                
                return .success(
                    output,
                    metadata: [
                        "text": text,
                        "field": fieldLabel ?? "current field",
                        "app": appName ?? "current app"
                    ]
                )
            }
        )
    }
}