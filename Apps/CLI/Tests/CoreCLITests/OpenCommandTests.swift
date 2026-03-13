import Foundation
import Testing
@testable import PeekabooCLI

struct OpenCommandResolutionTests {
    @Test
    func `resolves http url without modification`() throws {
        let url = try OpenCommand.resolveTarget("https://example.com")
        #expect(url.absoluteString == "https://example.com")
    }

    @Test
    func `resolves tilde-expanded path`() throws {
        let path = "~/Documents/test.txt"
        let url = try OpenCommand.resolveTarget(path, cwd: "/tmp") // cwd ignored for absolute
        let expected = NSString(string: path).expandingTildeInPath
        #expect(url.isFileURL)
        #expect(url.path == expected)
    }

    @Test
    func `resolves relative path against cwd`() throws {
        let url = try OpenCommand.resolveTarget("data/report.md", cwd: "/tmp/project")
        #expect(url.isFileURL)
        #expect(url.path == "/tmp/project/data/report.md")
    }
}

struct AppCommandLaunchOpenTargetTests {
    @Test
    func `resolves https target`() throws {
        let url = try AppCommand.LaunchSubcommand.resolveOpenTarget("https://peekaboo.app")
        #expect(url.absoluteString == "https://peekaboo.app")
    }

    @Test
    func `resolves relative file target with cwd override`() throws {
        let url = try AppCommand.LaunchSubcommand.resolveOpenTarget("notes.txt", cwd: "/tmp/workspace")
        #expect(url.path == "/tmp/workspace/notes.txt")
    }
}
