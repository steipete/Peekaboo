import Testing
import CoreGraphics
@testable import PeekabooCore

@Suite("FocusInfo Tests")
struct FocusInfoTests {
    
    @Test("FocusInfo initialization")
    func testFocusInfoInitialization() {
        let elementInfo = ElementInfo(
            role: "AXTextField",
            title: "Email Address",
            value: "test@example.com",
            bounds: CGRect(x: 100, y: 50, width: 300, height: 25),
            isEnabled: true,
            isVisible: true,
            subrole: nil,
            description: "Enter your email address"
        )
        
        let focusInfo = FocusInfo(
            app: "Mail",
            bundleId: "com.apple.mail",
            processId: 1234,
            element: elementInfo
        )
        
        #expect(focusInfo.app == "Mail")
        #expect(focusInfo.bundleId == "com.apple.mail")
        #expect(focusInfo.processId == 1234)
        #expect(focusInfo.element.role == "AXTextField")
    }
    
    @Test("ElementInfo text input detection")
    func testElementInfoTextInputDetection() {
        // Text field should be detected as text input
        let textField = ElementInfo(
            role: "AXTextField",
            title: "Name",
            value: "",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 30),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(textField.isTextInput == true)
        #expect(textField.canAcceptKeyboardInput == true)
        
        // Text area should be detected as text input
        let textArea = ElementInfo(
            role: "AXTextArea",
            title: "Comments",
            value: "",
            bounds: CGRect(x: 0, y: 0, width: 200, height: 100),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(textArea.isTextInput == true)
        #expect(textArea.canAcceptKeyboardInput == true)
        
        // Search field should be detected as text input
        let searchField = ElementInfo(
            role: "AXSearchField",
            title: "Search",
            value: "",
            bounds: CGRect(x: 0, y: 0, width: 150, height: 25),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(searchField.isTextInput == true)
        #expect(searchField.canAcceptKeyboardInput == true)
        
        // Secure text field should be detected as text input
        let passwordField = ElementInfo(
            role: "AXSecureTextField",
            title: "Password",
            value: "",
            bounds: CGRect(x: 0, y: 0, width: 150, height: 25),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(passwordField.isTextInput == true)
        #expect(passwordField.canAcceptKeyboardInput == true)
    }
    
    @Test("ElementInfo non-text input detection")
    func testElementInfoNonTextInputDetection() {
        // Button should not be text input but can accept keyboard input
        let button = ElementInfo(
            role: "AXButton",
            title: "Submit",
            value: nil,
            bounds: CGRect(x: 0, y: 0, width: 80, height: 30),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(button.isTextInput == false)
        #expect(button.canAcceptKeyboardInput == true) // Buttons can accept keyboard (spacebar, enter)
        
        // Static text should not accept keyboard input
        let staticText = ElementInfo(
            role: "AXStaticText",
            title: "Label",
            value: "Some text",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 20),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(staticText.isTextInput == false)
        #expect(staticText.canAcceptKeyboardInput == false)
        
        // Image should not accept keyboard input
        let image = ElementInfo(
            role: "AXImage",
            title: "Logo",
            value: nil,
            bounds: CGRect(x: 0, y: 0, width: 50, height: 50),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(image.isTextInput == false)
        #expect(image.canAcceptKeyboardInput == false)
    }
    
    @Test("ElementInfo disabled state")
    func testElementInfoDisabledState() {
        // Disabled text field should not accept keyboard input
        let disabledTextField = ElementInfo(
            role: "AXTextField",
            title: "Disabled Field",
            value: "",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 25),
            isEnabled: false,
            isVisible: true
        )
        
        #expect(disabledTextField.isTextInput == true) // Still a text input by type
        #expect(disabledTextField.canAcceptKeyboardInput == false) // But can't accept input when disabled
        
        // Disabled button should not accept keyboard input
        let disabledButton = ElementInfo(
            role: "AXButton",
            title: "Disabled Button",
            value: nil,
            bounds: CGRect(x: 0, y: 0, width: 80, height: 30),
            isEnabled: false,
            isVisible: true
        )
        
        #expect(disabledButton.canAcceptKeyboardInput == false)
    }
    
    @Test("ElementInfo web content detection")
    func testElementInfoWebContentDetection() {
        // Editable web content should be detected as text input
        let editableWebArea = ElementInfo(
            role: "AXWebArea",
            title: "Rich Text Editor",
            value: "",
            bounds: CGRect(x: 0, y: 0, width: 400, height: 200),
            isEnabled: true,
            isVisible: true,
            subrole: "AXContentEditable"
        )
        
        #expect(editableWebArea.isTextInput == true)
        #expect(editableWebArea.canAcceptKeyboardInput == true)
        
        // Regular web area should not be text input
        let regularWebArea = ElementInfo(
            role: "AXWebArea",
            title: "Web Page",
            value: nil,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            isEnabled: true,
            isVisible: true
        )
        
        #expect(regularWebArea.isTextInput == false)
        #expect(regularWebArea.canAcceptKeyboardInput == true) // Web areas can still accept keyboard input for navigation
    }
    
    @Test("ElementInfo type descriptions")
    func testElementInfoTypeDescriptions() {
        let textField = ElementInfo(
            role: "AXTextField",
            title: "Name",
            value: "",
            bounds: .zero,
            isEnabled: true,
            isVisible: true
        )
        #expect(textField.typeDescription == "text field")
        
        let button = ElementInfo(
            role: "AXButton",
            title: "Submit",
            value: nil,
            bounds: .zero,
            isEnabled: true,
            isVisible: true
        )
        #expect(button.typeDescription == "button")
        
        let searchField = ElementInfo(
            role: "AXSearchField",
            title: "Search",
            value: "",
            bounds: .zero,
            isEnabled: true,
            isVisible: true
        )
        #expect(searchField.typeDescription == "search field")
        
        let customRole = ElementInfo(
            role: "AXCustomElement",
            title: "Custom",
            value: nil,
            bounds: .zero,
            isEnabled: true,
            isVisible: true
        )
        #expect(customRole.typeDescription == "customelement")
    }
    
    @Test("FocusInfo convenience properties")
    func testFocusInfoConvenienceProperties() {
        let textFieldElement = ElementInfo(
            role: "AXTextField",
            title: "Email",
            value: "test@example.com",
            bounds: CGRect(x: 100, y: 50, width: 200, height: 25),
            isEnabled: true,
            isVisible: true
        )
        
        let focusInfo = FocusInfo(
            app: "Safari",
            bundleId: "com.apple.Safari",
            processId: 1234,
            element: textFieldElement
        )
        
        #expect(focusInfo.isTextInput == true)
        #expect(focusInfo.canAcceptKeyboardInput == true)
        #expect(focusInfo.humanDescription.contains("Email"))
        #expect(focusInfo.humanDescription.contains("Safari"))
    }
    
    @Test("FocusInfo dictionary conversion")
    func testFocusInfoDictionaryConversion() {
        let elementInfo = ElementInfo(
            role: "AXTextField",
            title: "Username",
            value: "john_doe",
            bounds: CGRect(x: 50, y: 100, width: 150, height: 30),
            isEnabled: true,
            isVisible: true,
            subrole: nil,
            description: "Enter username"
        )
        
        let focusInfo = FocusInfo(
            app: "LoginApp",
            bundleId: "com.example.loginapp",
            processId: 5678,
            element: elementInfo
        )
        
        let dict = focusInfo.toDictionary()
        
        #expect(dict["app"] as? String == "LoginApp")
        #expect(dict["bundleId"] as? String == "com.example.loginapp")
        #expect(dict["processId"] as? Int == 5678)
        
        let elementDict = dict["element"] as? [String: Any]
        #expect(elementDict != nil)
        #expect(elementDict?["role"] as? String == "AXTextField")
        #expect(elementDict?["title"] as? String == "Username")
        #expect(elementDict?["value"] as? String == "john_doe")
        #expect(elementDict?["isEnabled"] as? Bool == true)
        #expect(elementDict?["isVisible"] as? Bool == true)
        #expect(elementDict?["isTextInput"] as? Bool == true)
        #expect(elementDict?["canAcceptKeyboardInput"] as? Bool == true)
        #expect(elementDict?["typeDescription"] as? String == "text field")
        
        let boundsDict = elementDict?["bounds"] as? [String: Any]
        #expect(boundsDict != nil)
        #expect(boundsDict?["x"] as? CGFloat == 50)
        #expect(boundsDict?["y"] as? CGFloat == 100)
        #expect(boundsDict?["width"] as? CGFloat == 150)
        #expect(boundsDict?["height"] as? CGFloat == 30)
    }
    
    @Test("ElementInfo dictionary conversion")
    func testElementInfoDictionaryConversion() {
        let elementInfo = ElementInfo(
            role: "AXButton",
            title: "Cancel",
            value: nil,
            bounds: CGRect(x: 200, y: 300, width: 80, height: 35),
            isEnabled: false,
            isVisible: true,
            subrole: "AXCloseButton",
            description: "Cancel the operation"
        )
        
        let dict = elementInfo.toDictionary()
        
        #expect(dict["role"] as? String == "AXButton")
        #expect(dict["title"] as? String == "Cancel")
        #expect(dict["value"] == nil)
        #expect(dict["isEnabled"] as? Bool == false)
        #expect(dict["isVisible"] as? Bool == true)
        #expect(dict["subrole"] as? String == "AXCloseButton")
        #expect(dict["description"] as? String == "Cancel the operation")
        #expect(dict["isTextInput"] as? Bool == false)
        #expect(dict["canAcceptKeyboardInput"] as? Bool == false) // Disabled button can't accept input
        #expect(dict["typeDescription"] as? String == "button")
    }
}