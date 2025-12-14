import ApplicationServices
import Testing
@testable import PeekabooAutomationKit

@Suite(.serialized) @MainActor struct PermissionsServiceAppleEventTests {
    @Test func appleEventTargetDescriptorUsesBundleIdentifierType() throws {
        let bundleIdentifier = "com.apple.systemevents"

        var duplicatedDesc = try #require(
            PermissionsService.makeAppleEventTargetAddressDesc(bundleIdentifier: bundleIdentifier),
            "Expected PermissionsService to create a target address AEDesc")
        defer { AEDisposeDesc(&duplicatedDesc) }

        #expect(
            duplicatedDesc.descriptorType == DescType(typeApplicationBundleID),
            "Expected AppleEvent target descriptor to be a bundle identifier address descriptor")

        _ = try #require(duplicatedDesc.dataHandle, "Expected duplicated AEDesc to have a data handle")
    }

    @Test func appleEventTargetDescriptorDuplicationReturnsUniqueHandlesPerCall() throws {
        let bundleIdentifier = "com.apple.systemevents"

        var firstDesc = try #require(
            PermissionsService.makeAppleEventTargetAddressDesc(bundleIdentifier: bundleIdentifier),
            "Expected first duplicated AEDesc")
        defer { AEDisposeDesc(&firstDesc) }

        var secondDesc = try #require(
            PermissionsService.makeAppleEventTargetAddressDesc(bundleIdentifier: bundleIdentifier),
            "Expected second duplicated AEDesc")
        defer { AEDisposeDesc(&secondDesc) }

        let firstHandle = try #require(firstDesc.dataHandle, "Expected duplicated AEDesc instances to have data handles")
        let secondHandle = try #require(secondDesc.dataHandle, "Expected duplicated AEDesc instances to have data handles")

        #expect(
            UInt(bitPattern: firstHandle) != UInt(bitPattern: secondHandle),
            "Expected each call to return a fresh duplicated AEDesc handle")
    }
}
