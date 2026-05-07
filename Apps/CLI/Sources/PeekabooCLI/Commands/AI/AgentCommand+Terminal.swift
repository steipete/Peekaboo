import Darwin
import Dispatch
import Foundation
import PeekabooAgentRuntime
import PeekabooCore
import TauTUI

@MainActor
private final class TerminalModeGuard {
    private let fd: Int32
    private var original = termios()
    private var active = false

    init?(fd: Int32 = STDIN_FILENO) {
        guard isatty(fd) == 1 else { return nil }
        guard tcgetattr(fd, &self.original) == 0 else { return nil }

        var raw = self.original
        cfmakeraw(&raw)
        raw.c_lflag |= tcflag_t(ISIG) // keep signals like Ctrl+C enabled

        guard tcsetattr(fd, TCSANOW, &raw) == 0 else { return nil }
        self.fd = fd
        self.active = true
    }

    var fileDescriptor: Int32 {
        self.fd
    }

    func restore() {
        guard self.active else { return }
        _ = tcsetattr(self.fd, TCSANOW, &self.original)
        self.active = false
    }

    @MainActor
    deinit {
        self.restore()
    }
}

final class EscapeKeyMonitor {
    private var source: (any DispatchSourceRead)?
    private var terminalGuard: TerminalModeGuard?
    private let handler: @Sendable () async -> Void
    private let queue = DispatchQueue(label: "peekaboo.escape.monitor")

    init(handler: @escaping @Sendable () async -> Void) {
        self.handler = handler
    }

    func start() {
        guard self.source == nil else { return }
        guard let termGuard = TerminalModeGuard() else { return }

        let fd = termGuard.fileDescriptor
        let handler = self.handler
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: self.queue)

        source.setEventHandler {
            var buffer = [UInt8](repeating: 0, count: 16)
            let count = read(fd, &buffer, buffer.count)
            guard count > 0 else { return }
            if buffer[..<count].contains(0x1B) {
                Task.detached(priority: .userInitiated) {
                    await handler()
                }
            }
        }

        source.setCancelHandler {
            termGuard.restore()
        }

        source.resume()
        self.source = source
        self.terminalGuard = termGuard
    }

    func stop() {
        self.source?.cancel()
        self.source = nil
        self.terminalGuard = nil
    }
}

@available(macOS 14.0, *)
extension AgentCommand {
    func printChatWelcome(sessionId: String?, modelDescription: String, queueMode: QueueMode) {
        guard !self.quiet else { return }
        let header = [
            TerminalColor.cyan,
            TerminalColor.bold,
            "Interactive agent chat",
            TerminalColor.reset,
            " – model: ",
            modelDescription,
            " • queue: ",
            queueMode == .all ? "all" : "one-at-a-time"
        ].joined()
        print(header)
        if let sessionId {
            print("\(TerminalColor.dim)Resuming session \(sessionId.prefix(8))\(TerminalColor.reset)")
        } else {
            print("\(TerminalColor.dim)A new session will be created on the first prompt\(TerminalColor.reset)")
        }
        print()
    }

    func printChatHelpIntro() {
        guard !self.quiet else { return }
        print("Type /help for chat commands (Ctrl+C to exit).")
        self.printChatHelpMenu()
    }

    func printChatHelpMenu() {
        guard !self.quiet else { return }
        self.chatHelpLines.forEach { print($0) }
    }

    private var chatHelpText: String {
        """

        Chat commands:
          • Type any prompt and press Return to run it.
          • /help  Show this menu again.
          • Esc    Cancel the active run (if one is in progress).
          • Ctrl+C Cancel when running; exit immediately when idle.
          • Ctrl+D Exit when idle (EOF).

        """
    }

    var chatHelpLines: [String] {
        self.chatHelpText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private func printCapabilityFlag(_ label: String, supported: Bool, detail: String? = nil) {
        let status = supported ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.failure
        let detailSuffix = detail.map { " (\($0))" } ?? ""
        print("   • \(label): \(status)\(detailSuffix)")
    }

    /// Print detailed terminal detection debugging information
    func printTerminalDetectionDebug(_ capabilities: TerminalCapabilities, actualMode: OutputMode) {
        print("\n" + String(repeating: "=", count: 60))
        print("\(TerminalColor.bold)\(TerminalColor.cyan)TERMINAL DETECTION DEBUG (-vv)\(TerminalColor.reset)")
        print(String(repeating: "=", count: 60))

        print("[term] \(TerminalColor.bold)Terminal Type:\(TerminalColor.reset) \(capabilities.termType ?? "unknown")")
        print(
            "[size] \(TerminalColor.bold)Dimensions:\(TerminalColor.reset) \(capabilities.width)x\(capabilities.height)"
        )

        print("\(AgentDisplayTokens.Status.running) \(TerminalColor.bold)Capabilities:\(TerminalColor.reset)")
        self.printCapabilityFlag("Interactive", supported: capabilities.isInteractive, detail: "isatty check")
        self.printCapabilityFlag("Colors", supported: capabilities.supportsColors, detail: "ANSI support")
        self.printCapabilityFlag("True Color", supported: capabilities.supportsTrueColor, detail: "24-bit")
        print("   • Dimensions: \(capabilities.width)x\(capabilities.height)")

        print("[env] \(TerminalColor.bold)Environment:\(TerminalColor.reset)")
        self.printCapabilityFlag("CI Environment", supported: capabilities.isCI)
        self.printCapabilityFlag("Piped Output", supported: capabilities.isPiped)

        let env = ProcessInfo.processInfo.environment
        print("\(AgentDisplayTokens.Status.running) \(TerminalColor.bold)Environment Variables:\(TerminalColor.reset)")
        print("   • TERM: \(env["TERM"] ?? "not set")")
        print("   • COLORTERM: \(env["COLORTERM"] ?? "not set")")
        print("   • NO_COLOR: \(env["NO_COLOR"] != nil ? "set" : "not set")")
        print("   • FORCE_COLOR: \(env["FORCE_COLOR"] ?? "not set")")
        print("   • PEEKABOO_OUTPUT_MODE: \(env["PEEKABOO_OUTPUT_MODE"] ?? "not set")")

        let recommendedMode = capabilities.recommendedOutputMode
        print("[focus] \(TerminalColor.bold)Recommended Mode:\(TerminalColor.reset) \(recommendedMode.description)")
        print("[focus] \(TerminalColor.bold)Actual Mode:\(TerminalColor.reset) \(actualMode.description)")

        if recommendedMode != actualMode {
            let modeOverrideLine = [
                "\(AgentDisplayTokens.Status.warning)  ",
                "\(TerminalColor.yellow)Mode Override Detected\(TerminalColor.reset)",
                " - explicit flag or environment variable used"
            ].joined()
            print(modeOverrideLine)
        }

        if !capabilities.isInteractive || capabilities.isCI || capabilities.isPiped {
            print("   → Minimal mode (non-interactive/CI/piped)")
        } else if capabilities.supportsColors {
            print("   → Enhanced mode (colors available)")
        } else {
            print("   → Compact mode (basic terminal)")
        }

        print(String(repeating: "=", count: 60) + "\n")
    }
}
