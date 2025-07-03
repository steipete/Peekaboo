import Testing
import Foundation
@testable import peekaboo

@Suite("Version Tests")
struct VersionTests {
    
    @Test("Version follows semantic versioning format")
    func testSemanticVersioningFormat() {
        let version = Version.current
        
        // Should match X.Y.Z format
        let versionRegex = try! NSRegularExpression(pattern: #"^\d+\.\d+\.\d+$"#)
        let range = NSRange(location: 0, length: version.utf16.count)
        let matches = versionRegex.matches(in: version, range: range)
        
        #expect(!matches.isEmpty, "Version '\(version)' should follow semantic versioning (X.Y.Z)")
    }
    
    @Test("Version components are valid numbers")
    func testVersionComponentsAreNumbers() {
        let version = Version.current
        let components = version.split(separator: ".")
        
        #expect(components.count == 3)
        
        let major = try #require(Int(components[0]))
        let minor = try #require(Int(components[1]))
        let patch = try #require(Int(components[2]))
        
        #expect(major >= 0)
        #expect(minor >= 0)
        #expect(patch >= 0)
    }
    
    @Test("Version is consistent across calls")
    func testVersionConsistency() {
        let version1 = Version.current
        let version2 = Version.current
        
        #expect(version1 == version2)
    }
    
    @Test("Version string is not empty")
    func testVersionNotEmpty() {
        #expect(!Version.current.isEmpty)
        #expect(Version.current.count >= 5) // Minimum: "0.0.0"
    }
    
    @Test("Version can be used in user agent strings")
    func testVersionInUserAgent() {
        let userAgent = "Peekaboo/\(Version.current)"
        
        #expect(userAgent.hasPrefix("Peekaboo/"))
        #expect(userAgent.count > 9) // "Peekaboo/" + at least "0.0.0"
    }
}