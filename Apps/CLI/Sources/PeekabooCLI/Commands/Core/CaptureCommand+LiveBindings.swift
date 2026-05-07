import Commander
import PeekabooCore

extension CaptureLiveCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "live",
                abstract: "Capture live screen/window/region with change-aware sampling",
                version: "1.0.0"
            )
        }
    }
}

extension CaptureLiveCommand: AsyncRuntimeCommand {}

@MainActor
extension CaptureLiveCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.mode = values.singleOption("mode")
        self.windowTitle = values.singleOption("windowTitle")
        self.windowIndex = try values.decodeOption("windowIndex", as: Int.self)
        self.screenIndex = try values.decodeOption("screenIndex", as: Int.self)
        self.region = values.singleOption("region")
        if let parsedFocus: LiveCaptureFocus = try values
            .decodeOptionEnum("captureFocus") { self.captureFocus = parsedFocus }
        self.captureEngine = values.singleOption("captureEngine")
        self.duration = try values.decodeOption("duration", as: Double.self)
        self.idleFps = try values.decodeOption("idleFps", as: Double.self)
        self.activeFps = try values.decodeOption("activeFps", as: Double.self)
        self.threshold = try values.decodeOption("threshold", as: Double.self)
        self.heartbeatSec = try values.decodeOption("heartbeatSec", as: Double.self)
        self.quietMs = try values.decodeOption("quietMs", as: Int.self)
        self.maxFrames = try values.decodeOption("maxFrames", as: Int.self)
        self.maxMb = try values.decodeOption("maxMb", as: Int.self)
        self.resolutionCap = try values.decodeOption("resolutionCap", as: Double.self)
        self.diffStrategy = values.singleOption("diffStrategy")
        self.diffBudgetMs = try values.decodeOption("diffBudgetMs", as: Int.self)
        if values.flag("highlightChanges") { self.highlightChanges = true }
        self.path = values.singleOption("path")
        self.autocleanMinutes = try values.decodeOption("autocleanMinutes", as: Int.self)
        self.videoOut = values.singleOption("videoOut")
    }
}
