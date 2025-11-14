import Foundation
import Testing
@testable import PeekabooCLI

@Suite("OpenCommand Target Resolution Tests")
struct OpenCommandResolutionTests {
    @Test("resolves http url without modification")
    func resolvesHTTPURL() throws {
        let url = try OpenCommand.resolveTarget("https://example.com")
        #expect(url.absoluteString == "https://example.com")
    }

    @Test("resolves tilde-expanded path")
    func resolvesHomePath() throws {
        let path = "~/Documents/test.txt"
        let url = try OpenCommand.resolveTarget(path, cwd: "/tmp") // cwd ignored for absolute
        let expected = NSString(string: path).expandingTildeInPath
        #expect(url.isFileURL)
        #expect(url.path == expected)
    }

    @Test("resolves relative path against cwd")
    func resolvesRelativePath() throws {
        let url = try OpenCommand.resolveTarget("data/report.md", cwd: "/tmp/project")
        #expect(url.isFileURL)
        #expect(url.path == "/tmp/project/data/report.md")
    }
}

@Suite("AppCommand Launch open target resolution")
struct AppCommandLaunchOpenTargetTests {
    @Test("resolves https target")
    func resolvesURL() throws {
        let url = try AppCommand.LaunchSubcommand.resolveOpenTarget("https://peekaboo.app")
        #expect(url.absoluteString == "https://peekaboo.app")
    }

    @Test("resolves relative file target with cwd override")
    func resolvesRelativeFile() throws {
        let url = try AppCommand.LaunchSubcommand.resolveOpenTarget("notes.txt", cwd: "/tmp/workspace")
        #expect(url.path == "/tmp/workspace/notes.txt")
    }
}
