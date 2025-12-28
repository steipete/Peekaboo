import AppKit
import UniformTypeIdentifiers
import XCTest

@testable import PeekabooAutomationKit

@available(macOS 14.0, *)
@MainActor
final class ClipboardWriteRequestTests: XCTestCase {
    func testTextRepresentationsIncludePlainTextAndString() {
        let data = Data("hello".utf8)
        let reps = ClipboardWriteRequest.textRepresentations(from: data)
        let types = reps.map(\.utiIdentifier)

        XCTAssertTrue(types.contains(UTType.plainText.identifier))
        XCTAssertTrue(types.contains(NSPasteboard.PasteboardType.string.rawValue))
        XCTAssertEqual(Set(types).count, types.count)
    }
}
