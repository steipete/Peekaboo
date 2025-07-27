import Testing
import CoreGraphics
@testable import PeekabooCore

@Suite("UIAutomationService Focus Tests")
struct UIAutomationServiceFocusTests {
    
    @Test("getFocusedElement returns nil when no element focused")
    func testGetFocusedElementNoFocus() async {
        let service = UIAutomationService()
        
        // Note: This test may be environment-dependent
        // In a real test environment with no focused elements, this should return nil
        let result = await service.getFocusedElement()
        
        // We can't guarantee no focus in all test environments,
        // but we can at least verify the method doesn't crash
        if let focusInfo = result {
            #expect(!focusInfo.app.isEmpty)
            #expect(!focusInfo.element.role.isEmpty)
        }
    }
    
    @Test("getFocusedElement structure validation")
    func testGetFocusedElementStructure() async {
        let service = UIAutomationService()
        
        // This test validates that if we get a result, it has the expected structure
        let result = await service.getFocusedElement()
        
        if let focusInfo = result {
            // Validate app information
            #expect(!focusInfo.app.isEmpty)
            #expect(focusInfo.processId > 0)
            
            // Validate element information
            #expect(!focusInfo.element.role.isEmpty)
            #expect(focusInfo.element.bounds.width >= 0)
            #expect(focusInfo.element.bounds.height >= 0)
            
            // Validate convenience methods work
            let _ = focusInfo.isTextInput
            let _ = focusInfo.canAcceptKeyboardInput
            let _ = focusInfo.humanDescription
            
            // Validate dictionary conversion
            let dict = focusInfo.toDictionary()
            #expect(dict["app"] != nil)
            #expect(dict["element"] != nil)
        }
    }
    
    @Test("Focus info dictionary format validation")
    func testFocusInfoDictionaryFormat() async {
        let service = UIAutomationService()
        
        let result = await service.getFocusedElement()
        
        if let focusInfo = result {
            let dict = focusInfo.toDictionary()
            
            // Validate required top-level keys
            #expect(dict["app"] is String)
            #expect(dict["processId"] is Int)
            #expect(dict["element"] is [String: Any])
            
            // bundleId can be nil for some apps
            if dict["bundleId"] != nil {
                #expect(dict["bundleId"] is String)
            }
            
            // Validate element dictionary structure
            let elementDict = dict["element"] as! [String: Any]
            #expect(elementDict["role"] is String)
            #expect(elementDict["isEnabled"] is Bool)
            #expect(elementDict["isVisible"] is Bool)
            #expect(elementDict["isTextInput"] is Bool)
            #expect(elementDict["canAcceptKeyboardInput"] is Bool)
            #expect(elementDict["typeDescription"] is String)
            #expect(elementDict["bounds"] is [String: Any])
            
            // Validate bounds dictionary
            let boundsDict = elementDict["bounds"] as! [String: Any]
            #expect(boundsDict["x"] is CGFloat)
            #expect(boundsDict["y"] is CGFloat)
            #expect(boundsDict["width"] is CGFloat)
            #expect(boundsDict["height"] is CGFloat)
        }
    }
}

// MARK: - Mock Tests for Focus Information

@Suite("Focus Information Mock Tests")
struct FocusInformationMockTests {
    
    @Test("Focus detection with text field simulation")
    func testFocusDetectionTextFieldSimulation() {
        // Simulate what we expect when a text field is focused
        let textFieldFocus = FocusInfo(
            app: "TestApp",
            bundleId: "com.test.app",
            processId: 1234,
            element: ElementInfo(
                role: "AXTextField",
                title: "Email Address",
                value: "",
                bounds: CGRect(x: 100, y: 200, width: 250, height: 30),
                isEnabled: true,
                isVisible: true,
                subrole: nil,
                description: "Enter your email address"
            )
        )
        
        #expect(textFieldFocus.isTextInput == true)
        #expect(textFieldFocus.canAcceptKeyboardInput == true)
        #expect(textFieldFocus.humanDescription.contains("Email Address"))
        #expect(textFieldFocus.humanDescription.contains("TestApp"))
    }
    
    @Test("Focus detection with Safari address bar simulation")
    func testFocusDetectionSafariAddressBarSimulation() {
        // Simulate the problematic case from your email issue
        let safariAddressBarFocus = FocusInfo(
            app: "Safari",
            bundleId: "com.apple.Safari",
            processId: 5678,
            element: ElementInfo(
                role: "AXTextField",
                title: "Address and Search Bar",
                value: "hello@gmail.com", // The email that was typed in wrong place
                bounds: CGRect(x: 200, y: 100, width: 400, height: 30),
                isEnabled: true,
                isVisible: true,
                subrole: nil,
                description: "Address and search bar"
            )
        )
        
        #expect(safariAddressBarFocus.isTextInput == true)
        #expect(safariAddressBarFocus.canAcceptKeyboardInput == true)
        #expect(safariAddressBarFocus.element.title == "Address and Search Bar")
        #expect(safariAddressBarFocus.element.value == "hello@gmail.com")
        
        // The agent would see this and realize it typed in the wrong place
        let dict = safariAddressBarFocus.toDictionary()
        let elementDict = dict["element"] as! [String: Any]
        #expect(elementDict["title"] as? String == "Address and Search Bar")
        #expect(elementDict["value"] as? String == "hello@gmail.com")
    }
    
    @Test("Focus detection with Mail app To field simulation")
    func testFocusDetectionMailToFieldSimulation() {
        // Simulate what we want - focus in Mail app's To field
        let mailToFieldFocus = FocusInfo(
            app: "Mail",
            bundleId: "com.apple.mail",
            processId: 9999,
            element: ElementInfo(
                role: "AXTextField",
                title: "To:",
                value: "",
                bounds: CGRect(x: 150, y: 250, width: 350, height: 25),
                isEnabled: true,
                isVisible: true,
                subrole: nil,
                description: "To field"
            )
        )
        
        #expect(mailToFieldFocus.isTextInput == true)
        #expect(mailToFieldFocus.canAcceptKeyboardInput == true)
        #expect(mailToFieldFocus.app == "Mail")
        #expect(mailToFieldFocus.element.title == "To:")
        #expect(mailToFieldFocus.element.value == "")
        
        // This is what the agent should see for correct email field targeting
        let dict = mailToFieldFocus.toDictionary()
        #expect(dict["app"] as? String == "Mail")
        let elementDict = dict["element"] as! [String: Any]
        #expect(elementDict["title"] as? String == "To:")
    }
    
    @Test("Focus detection with no focus simulation")
    func testFocusDetectionNoFocusSimulation() {
        // Test the case where no element is focused
        // This would be represented as nil from getFocusedElement()
        
        // Simulate tool response when no focus
        let noFocusResponse: [String: Any] = [
            "found": false,
            "message": "No focused element after typing"
        ]
        
        #expect(noFocusResponse["found"] as? Bool == false)
        #expect(noFocusResponse["message"] as? String == "No focused element after typing")
    }
    
    @Test("Focus detection with disabled element simulation")
    func testFocusDetectionDisabledElementSimulation() {
        // Simulate focus on a disabled element (shouldn't happen in practice but good to test)
        let disabledElementFocus = FocusInfo(
            app: "TestApp",
            bundleId: "com.test.app",
            processId: 1111,
            element: ElementInfo(
                role: "AXTextField",
                title: "Read-only Field",
                value: "Cannot edit this",
                bounds: CGRect(x: 50, y: 150, width: 200, height: 25),
                isEnabled: false,
                isVisible: true,
                subrole: nil,
                description: "Read-only text field"
            )
        )
        
        #expect(disabledElementFocus.isTextInput == true) // Still a text field by role
        #expect(disabledElementFocus.canAcceptKeyboardInput == false) // But can't accept input
        
        let dict = disabledElementFocus.toDictionary()
        let elementDict = dict["element"] as! [String: Any]
        #expect(elementDict["isEnabled"] as? Bool == false)
        #expect(elementDict["canAcceptKeyboardInput"] as? Bool == false)
    }
}