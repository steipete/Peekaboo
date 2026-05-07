import Commander
import PeekabooCore

typealias LiveCaptureMode = PeekabooCore.CaptureMode
typealias LiveCaptureFocus = PeekabooCore.CaptureFocus
typealias LiveCaptureSessionResult = PeekabooCore.CaptureSessionResult

@MainActor
struct CaptureCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "capture",
                abstract: "Capture live screens/windows or ingest a video and extract frames",
                subcommands: [CaptureLiveCommand.self, CaptureVideoCommand.self, CaptureWatchAlias.self],
                showHelpOnEmptyInvocation: true
            )
        }
    }
}
