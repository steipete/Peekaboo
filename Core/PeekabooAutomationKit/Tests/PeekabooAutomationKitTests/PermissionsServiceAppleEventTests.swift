import ApplicationServices
import XCTest
@testable import PeekabooAutomationKit

@MainActor
final class PermissionsServiceAppleEventTests: XCTestCase {
    func testAppleEventTargetDescriptorUsesBundleIdentifierType() {
        let bundleIdentifier = "com.apple.systemevents"

        guard var duplicatedDesc = PermissionsService
            .makeAppleEventTargetAddressDesc(bundleIdentifier: bundleIdentifier)
        else {
            XCTFail("Expected PermissionsService to create a target address AEDesc")
            return
        }
        defer { AEDisposeDesc(&duplicatedDesc) }

        XCTAssertEqual(
            duplicatedDesc.descriptorType,
            DescType(typeApplicationBundleID),
            "Expected AppleEvent target descriptor to be a bundle identifier address descriptor")

        guard duplicatedDesc.dataHandle != nil else {
            XCTFail("Expected duplicated AEDesc to have a data handle")
            return
        }
    }

    func testAppleEventTargetDescriptorDuplicationReturnsUniqueHandlesPerCall() {
        let bundleIdentifier = "com.apple.systemevents"

        guard var firstDesc = PermissionsService
            .makeAppleEventTargetAddressDesc(bundleIdentifier: bundleIdentifier)
        else {
            XCTFail("Expected first duplicated AEDesc")
            return
        }
        defer { AEDisposeDesc(&firstDesc) }

        guard var secondDesc = PermissionsService
            .makeAppleEventTargetAddressDesc(bundleIdentifier: bundleIdentifier)
        else {
            XCTFail("Expected second duplicated AEDesc")
            return
        }
        defer { AEDisposeDesc(&secondDesc) }

        guard let firstHandle = firstDesc.dataHandle, let secondHandle = secondDesc.dataHandle else {
            XCTFail("Expected duplicated AEDesc instances to have data handles")
            return
        }

        XCTAssertNotEqual(
            UInt(bitPattern: firstHandle),
            UInt(bitPattern: secondHandle),
            "Expected each call to return a fresh duplicated AEDesc handle")
    }
}
