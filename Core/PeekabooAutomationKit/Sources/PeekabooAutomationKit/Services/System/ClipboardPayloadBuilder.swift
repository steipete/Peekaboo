import AppKit
import Foundation
import UniformTypeIdentifiers

public enum ClipboardPayloadBuilder {
    public static func textRequest(
        text: String,
        alsoText: String? = nil,
        allowLarge: Bool = false) throws -> ClipboardWriteRequest
    {
        guard let data = text.data(using: .utf8) else {
            throw ClipboardServiceError.writeFailed("Unable to encode text as UTF-8.")
        }
        return ClipboardWriteRequest(
            representations: ClipboardWriteRequest.textRepresentations(from: data),
            alsoText: alsoText,
            allowLarge: allowLarge)
    }

    public static func dataRequest(
        data: Data,
        uti: UTType,
        alsoText: String? = nil,
        allowLarge: Bool = false) -> ClipboardWriteRequest
    {
        ClipboardWriteRequest(
            representations: [ClipboardRepresentation(utiIdentifier: uti.identifier, data: data)],
            alsoText: alsoText,
            allowLarge: allowLarge)
    }

    public static func dataRequest(
        data: Data,
        utiIdentifier: String,
        alsoText: String? = nil,
        allowLarge: Bool = false) -> ClipboardWriteRequest
    {
        ClipboardWriteRequest(
            representations: [ClipboardRepresentation(utiIdentifier: utiIdentifier, data: data)],
            alsoText: alsoText,
            allowLarge: allowLarge)
    }

    public static func base64Request(
        base64: String,
        utiIdentifier: String,
        alsoText: String? = nil,
        allowLarge: Bool = false) throws -> ClipboardWriteRequest
    {
        guard let data = Data(base64Encoded: base64) else {
            throw ClipboardServiceError.writeFailed("Invalid base64 payload.")
        }
        return self.dataRequest(
            data: data,
            utiIdentifier: utiIdentifier,
            alsoText: alsoText,
            allowLarge: allowLarge)
    }
}
