import AppKit
import UniformTypeIdentifiers
import XCTest

@testable import PeekabooAutomationKit

@available(macOS 14.0, *)
@MainActor
final class ClipboardWriteRequestTests: XCTestCase {
    func testTextRepresentationsIncludePlainTextAndString() {
        let request = try? ClipboardPayloadBuilder.textRequest(text: "hello")
        let types = request?.representations.map(\.utiIdentifier) ?? []

        XCTAssertTrue(types.contains(UTType.plainText.identifier))
        XCTAssertTrue(types.contains(NSPasteboard.PasteboardType.string.rawValue))
        XCTAssertEqual(Set(types).count, types.count)
    }
}
