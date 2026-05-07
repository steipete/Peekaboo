import Foundation

extension ConfigurationManager {
    /// Load credentials from file
    func loadCredentials() {
        guard FileManager.default.fileExists(atPath: Self.credentialsPath) else {
            return
        }

        do {
            let contents = try String(contentsOfFile: Self.credentialsPath)
            let lines = contents.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }

                if let equalIndex = trimmed.firstIndex(of: "=") {
                    let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(trimmed[trimmed.index(after: equalIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty, !value.isEmpty {
                        self.credentials[key] = value
                    }
                }
            }
        } catch {
            // Silently ignore credential loading errors.
        }
    }

    /// Save credentials to file with proper permissions
    public func saveCredentials(_ newCredentials: [String: String]) throws {
        newCredentials.forEach { self.credentials[$0.key] = $0.value }

        try FileManager.default.createDirectory(
            atPath: Self.baseDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])

        let header = [
            "# Peekaboo credentials file",
            "# This file contains sensitive API keys and should not be shared",
            "",
        ]
        let body = self.credentials.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }
        let content = (header + body).joined(separator: "\n")

        try content.write(
            to: URL(fileURLWithPath: Self.credentialsPath),
            atomically: true,
            encoding: .utf8)

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: Self.credentialsPath)
    }

    /// Set or update a credential
    public func setCredential(key: String, value: String) throws {
        self.loadCredentials()
        try self.saveCredentials([key: value])
    }

    public func removeCredential(key: String) throws {
        self.loadCredentials()
        self.credentials.removeValue(forKey: key)

        if self.credentials.isEmpty {
            if FileManager.default.fileExists(atPath: Self.credentialsPath) {
                try FileManager.default.removeItem(atPath: Self.credentialsPath)
            }
            return
        }

        try self.saveCredentials([:])
    }

    func validOAuthAccessToken(prefix: String) -> String? {
        self.loadCredentials()
        guard let token = self.credentials["\(prefix)_ACCESS_TOKEN"] else { return nil }
        guard let expiryString = self.credentials["\(prefix)_ACCESS_EXPIRES"],
              let expiryInt = Int(expiryString) else { return token }
        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiryInt))
        if expiryDate > Date() {
            return token
        }
        return nil
    }

    /// Read a credential by key (loads from disk if needed)
    public func credentialValue(for key: String) -> String? {
        self.loadCredentials()
        return self.credentials[key]
    }
}
