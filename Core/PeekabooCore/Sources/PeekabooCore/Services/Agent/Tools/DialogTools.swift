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
                    "button": .string(
                        description: "Button label to click (e.g., 'OK', 'Cancel', 'Save')",
                        required: true
                    ),
                    "app": .string(
                        description: "Optional: Application name",
                        required: false
                    )
                ],
                required: ["button"]
            ),
            handler: { params, context in
                let buttonLabel = try params.string("button")
                let appName = params.string("app")
                
                try await context.dialog.clickDialogButton(
                    buttonLabel: buttonLabel,
                    in: appName
                )
                
                return .success(
                    "Clicked '\(buttonLabel)' button in dialog",
                    metadata: "button", buttonLabel,
                    "app", appName ?? "current app"
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
                    "text": .string(
                        description: "Text to enter",
                        required: true
                    ),
                    "field": .string(
                        description: "Optional: Field label or placeholder text",
                        required: false
                    ),
                    "app": .string(
                        description: "Optional: Application name",
                        required: false
                    ),
                    "clear_first": .boolean(
                        description: "Clear the field before typing (default: true)",
                        required: false
                    )
                ],
                required: ["text"]
            ),
            handler: { params, context in
                let text = try params.string("text")
                let fieldLabel = params.string("field")
                let appName = params.string("app")
                let clearFirst = params.bool("clear_first", default: true)
                
                // Find and focus the dialog
                let dialogInfo = try await context.dialog.findActiveDialog(in: appName)
                
                // Find the text field
                if let fieldLabel = fieldLabel {
                    // Find specific field
                    let element = try await findElementWithRetry(
                        criteria: .label(fieldLabel),
                        in: dialogInfo.applicationName,
                        context: context
                    )
                    
                    // Click to focus
                    try await element.performAction(.press)
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                } else {
                    // Find first text field in dialog
                    let textFields = dialogInfo.textFields
                    guard !textFields.isEmpty else {
                        throw PeekabooError.elementNotFound(
                            type: "text field",
                            in: "dialog"
                        )
                    }
                    
                    // Click the first field
                    let firstField = textFields[0]
                    let location = CGPoint(
                        x: firstField.bounds.midX,
                        y: firstField.bounds.midY
                    )
                    try await context.uiAutomation.click(at: location)
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                }
                
                // Clear if requested
                if clearFirst {
                    try await context.uiAutomation.pressKey(
                        key: .a,
                        modifiers: [.command]
                    )
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                    try await context.uiAutomation.pressKey(key: .delete)
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                }
                
                // Type the text
                try await context.uiAutomation.typeText(text)
                
                var output = "Entered text in dialog"
                if let fieldLabel = fieldLabel {
                    output += " field '\(fieldLabel)'"
                }
                
                return .success(
                    output,
                    metadata: "text", text,
                    "field", fieldLabel ?? "first field",
                    "dialog", dialogInfo.title ?? "untitled dialog",
                    "app", dialogInfo.applicationName
                )
            }
        )
    }
}