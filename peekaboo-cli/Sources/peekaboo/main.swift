import ArgumentParser
import Foundation

@main
@available(macOS 14.0, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
struct PeekabooCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "A cross-platform utility for screen capture, application listing, and window management",
        version: Version.current,
        subcommands: [ImageCommand.self, ListCommand.self],
        defaultSubcommand: ImageCommand.self
    )

    func run() async throws {
        // Check platform support
        guard PlatformFactory.isSupported else {
            print("❌ Peekaboo is not supported on this platform (\(PlatformFactory.currentPlatform))")
            throw ExitCode.failure
        }
        
        // Show platform capabilities if running without subcommand
        let capabilities = PlatformFactory.capabilities
        print("🌍 Peekaboo running on \(PlatformFactory.currentPlatform)")
        print("📋 Platform capabilities:")
        print("   Screen Capture: \(capabilities.screenCapture ? "✅" : "❌")")
        print("   Window Management: \(capabilities.windowManagement ? "✅" : "❌")")
        print("   Application Finding: \(capabilities.applicationFinding ? "✅" : "❌")")
        print("   Permissions: \(capabilities.permissions ? "✅" : "❌")")
        
        if !capabilities.isFullySupported {
            print("⚠️  Some features may be limited on this platform")
        }
    }
}

