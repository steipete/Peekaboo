import Foundation
@testable import peekaboo
import Testing

@Suite("Version Tests")
struct VersionTests {
    @Test("Version follows semantic versioning format")
    func semanticVersioningFormat() {
        let version = Version.current

        // Version should be in format "Peekaboo X.Y.Z" or "Peekaboo X.Y.Z-prerelease"
        let versionRegex = try! NSRegularExpression(pattern: #"^Peekaboo \d+\.\d+\.\d+(-[\w\.]+)?$"#)
        let range = NSRange(location: 0, length: version.utf16.count)
        let matches = versionRegex.matches(in: version, range: range)

        #expect(!matches.isEmpty, "Version '\(version)' should follow semantic versioning format")
    }

    @Test("Version components are valid numbers")
    func versionComponentsAreNumbers() throws {
        let version = Version.current

        // Remove "Peekaboo " prefix
        let versionNumber = version.replacingOccurrences(of: "Peekaboo ", with: "")
        
        // Split by prerelease identifier first
        let versionParts = versionNumber.split(separator: "-")
        let semverPart = String(versionParts[0])
        
        let components = semverPart.split(separator: ".")

        #expect(components.count == 3)

        let major = try #require(Int(components[0]))
        let minor = try #require(Int(components[1]))
        let patch = try #require(Int(components[2]))

        #expect(major >= 0)
        #expect(minor >= 0)
        #expect(patch >= 0)
    }

    @Test("Version is consistent across calls")
    func versionConsistency() {
        let version1 = Version.current
        let version2 = Version.current

        #expect(version1 == version2)
    }

    @Test("Version string is not empty")
    func versionNotEmpty() {
        #expect(!Version.current.isEmpty)
        #expect(Version.current.count >= 14) // Minimum: "Peekaboo 0.0.0"
    }

    @Test("Version can be used in user agent strings")
    func versionInUserAgent() {
        let userAgent = "Peekaboo/\(Version.current)"

        #expect(userAgent.hasPrefix("Peekaboo/"))
        #expect(userAgent.count > 18) // "Peekaboo/" + "Peekaboo " + at least "0.0.0"
    }
}
