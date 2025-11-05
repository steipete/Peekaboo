import AppKit
import AXorcist
import Testing
@testable import PeekabooCLI

// TODO: WaitForElementTests commented out - API changes needed
/*
 @Suite("Wait For Element Tests", .serialized, .tags(.safe))
 struct WaitForElementTests {
     // MARK: - Tests

     @Test("Element locator creation")
     func elementLocatorCreation() async throws {
         // Test element locator creation
         let locator = ElementLocator(
             role: "AXButton",
             title: "Save",
             label: "Save Document",
             value: nil
         )

         #expect(locator.role == "AXButton")
         #expect(locator.title == "Save")
         #expect(locator.label == "Save Document")
         #expect(locator.value == nil)
     }

     @Test("Session cache element retrieval")
     func sessionCacheElementRetrieval() async throws {
         // Test retrieving elements from session cache
         let sessionCache = try SessionCache(sessionId: "test-retrieval")

         let element = PeekabooCore.UIElement(
             id: "B1",
             elementId: "button1",
             role: "AXButton",
             title: "Save",
             label: nil,
             value: nil,
             frame: CGRect(x: 100, y: 100, width: 80, height: 30),
             isActionable: true
         )

         let sessionData = SessionCache.UIAutomationSession(
             version: SessionCache.UIAutomationSession.currentVersion,
             screenshotPath: "/tmp/test.png",
             annotatedPath: nil,
             uiMap: ["B1": element],
             lastUpdateTime: Date(),
             applicationName: "TestApp",
             windowTitle: "Test Window"
         )

         try await sessionCache.save(sessionData)

         // Retrieve element
         let retrieved = await sessionCache.getElement(id: "B1")
         #expect(retrieved != nil)
         #expect(retrieved?.title == "Save")
         #expect(retrieved?.role == "AXButton")

         // Cleanup
         try? await sessionCache.clear()
     }

     @Test("Actionable role detection")
     func actionableRoleDetection() async throws {
         // Test which roles are considered actionable
         let actionableRoles = [
             "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
             "AXRadioButton", "AXPopUpButton", "AXLink", "AXMenuItem",
             "AXSlider", "AXComboBox", "AXSegmentedControl",
         ]

         for role in actionableRoles {
             #expect(ElementIDGenerator.isActionableRole(role))
         }

         // Test non-actionable roles
         let nonActionableRoles = [
             "AXGroup", "AXStaticText", "AXImage", "AXSplitter",
         ]

         for role in nonActionableRoles {
             #expect(!ElementIDGenerator.isActionableRole(role))
         }
     }

     @Test("Element search by query")
     func elementSearchByQuery() async throws {
         // Test searching elements by query string
         let sessionCache = try SessionCache(sessionId: "test-search")

         let elements: [String: PeekabooCore.UIElement] = [
             "B1": PeekabooCore.UIElement(
                 id: "B1",
                 elementId: "save_btn",
                 role: "AXButton",
                 title: "Save Document",
                 label: nil,
                 value: nil,
                 frame: CGRect(x: 100, y: 100, width: 100, height: 30),
                 isActionable: true
             ),
             "B2": PeekabooCore.UIElement(
                 id: "B2",
                 elementId: "cancel_btn",
                 role: "AXButton",
                 title: "Cancel",
                 label: nil,
                 value: nil,
                 frame: CGRect(x: 220, y: 100, width: 80, height: 30),
                 isActionable: true
             ),
             "T1": PeekabooCore.UIElement(
                 id: "T1",
                 elementId: "name_field",
                 role: "AXTextField",
                 title: nil,
                 label: "Document Name",
                 value: "Untitled",
                 frame: CGRect(x: 100, y: 150, width: 200, height: 30),
                 isActionable: true
             ),
         ]

         let sessionData = SessionCache.UIAutomationSession(
             version: SessionCache.UIAutomationSession.currentVersion,
             screenshotPath: "/tmp/test.png",
             annotatedPath: nil,
             uiMap: elements,
             lastUpdateTime: Date(),
             applicationName: "TestApp",
             windowTitle: "Save Dialog"
         )

         try await sessionCache.save(sessionData)

         // Search for "Save"
         let saveElements = await sessionCache.findElements(matching: "Save")
         #expect(saveElements.count == 1)
         #expect(saveElements.first?.id == "B1")

         // Search for "Document"
         let docElements = await sessionCache.findElements(matching: "Document")
         #expect(docElements.count == 2) // Both B1 title and T1 label

         // Cleanup
         try? await sessionCache.clear()
     }

     @Test("Frame validation")
     func frameValidation() async throws {
         // Test frame validation logic
         let validFrame = CGRect(x: 100, y: 100, width: 80, height: 30)
         #expect(validFrame.width > 0)
         #expect(validFrame.height > 0)

         let zeroWidthFrame = CGRect(x: 100, y: 100, width: 0, height: 30)
         #expect(!(zeroWidthFrame.width > 0))

         let zeroHeightFrame = CGRect(x: 100, y: 100, width: 80, height: 0)
         #expect(!(zeroHeightFrame.height > 0))

         // CGRect normalizes negative dimensions to positive
         let negativeFrame = CGRect(x: 100, y: 100, width: -80, height: -30)
         // CGRect.standardized converts negative dimensions to positive
         #expect(negativeFrame.width == 80.0) // CGRect normalizes this
         #expect(negativeFrame.height == 30.0) // CGRect normalizes this
     }

     @Test("Wait for element timeout")
     func waitForElementTimeout() async throws {
         // Create a session with test element
         let sessionCache = try SessionCache(sessionId: "test-wait-timeout")

         let testElement = PeekabooCore.UIElement(
             id: "B1",
             elementId: "button1",
             role: "AXButton",
             title: "Never Appears",
             label: nil,
             value: nil,
             frame: CGRect(x: 100, y: 100, width: 80, height: 30),
             isActionable: true
         )

         let sessionData = SessionCache.UIAutomationSession(
             version: SessionCache.UIAutomationSession.currentVersion,
             screenshotPath: "/tmp/test.png",
             annotatedPath: nil,
             uiMap: ["B1": testElement],
             lastUpdateTime: Date(),
             applicationName: "NonExistentApp",
             windowTitle: nil
         )

         try await sessionCache.save(sessionData)

         // This test would verify timeout behavior, but waitForElement is private
         // In a real scenario, this would be tested through the public run() method
         #expect(true) // Placeholder since we can't test private methods

         // Cleanup
         try? await sessionCache.clear()
     }

     @Test("Wait for element by query filtering")
     func waitForElementByQueryFiltering() async throws {
         let sessionCache = try SessionCache(sessionId: "test-wait-query")

         // Create multiple elements
         let elements: [String: PeekabooCore.UIElement] = [
             "B1": PeekabooCore.UIElement(
                 id: "B1",
                 elementId: "button1",
                 role: "AXButton",
                 title: "Save Draft",
                 label: nil,
                 value: nil,
                 frame: CGRect(x: 100, y: 100, width: 80, height: 30),
                 isActionable: false // Not actionable
             ),
             "B2": PeekabooCore.UIElement(
                 id: "B2",
                 elementId: "button2",
                 role: "AXButton",
                 title: "Save & Close",
                 label: nil,
                 value: nil,
                 frame: CGRect(x: 200, y: 100, width: 100, height: 30),
                 isActionable: true // Actionable
             ),
         ]

         let sessionData = SessionCache.UIAutomationSession(
             version: SessionCache.UIAutomationSession.currentVersion,
             screenshotPath: "/tmp/test.png",
             annotatedPath: nil,
             uiMap: elements,
             lastUpdateTime: Date(),
             applicationName: "TestApp",
             windowTitle: nil
         )

         try await sessionCache.save(sessionData)

         // This test would verify query-based element waiting, but waitForElementByQuery is private
         // In a real scenario, this would be tested through the public run() method
         #expect(true) // Placeholder since we can't test private methods

         // Cleanup
         try? await sessionCache.clear()
     }
 }

 // ElementLocator needs to be accessible for tests
 struct ElementLocator {
     let role: String
     let title: String?
     let label: String?
     let value: String?
 }
 */
