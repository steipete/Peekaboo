struct ClipboardCommandResult: Codable {
    let action: String
    let uti: String?
    let size: Int?
    let filePath: String?
    let slot: String?
    let text: String?
    let textPreview: String?
    let dataBase64: String?
    let verification: ClipboardVerifyResult?
}

struct ClipboardVerifyResult: Codable {
    let ok: Bool
    let verifiedTypes: [String]
    let skippedTypes: [String]?
}
