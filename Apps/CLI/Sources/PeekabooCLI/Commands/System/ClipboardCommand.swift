import Commander
import Foundation
import PeekabooCore
import UniformTypeIdentifiers

@available(macOS 14.0, *)
@MainActor
struct ClipboardCommand: OutputFormattable, RuntimeOptionsConfigurable {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "clipboard",
                abstract: "Read/write the macOS clipboard (text, images, files)",
                discussion: """
                Actions:
                  get     Read the clipboard. Use --prefer <uti> or --output <path|-> for binary.
                  set     Write text, file/image, or base64+UTI. --also-text adds a text companion.
                  clear   Empty the clipboard.
                  save    Snapshot clipboard to a slot (default: \"0\").
                  restore Restore a previously saved slot.
                  load    Shortcut for set with --file-path.
                """,
                showHelpOnEmptyInvocation: true
            )
        }
    }

    @Option(name: .shortAndLong, help: "Action: get, set, clear, save, restore, load")
    var action: String

    @Option(name: .long, help: "Text to set")
    var text: String?

    @Option(name: .long, help: "Path to file to copy")
    var filePath: String?

    @Option(name: .long, help: "Path to image to copy (alias of file-path)")
    var imagePath: String?

    @Option(name: .long, help: "Base64 data to copy")
    var dataBase64: String?

    @Option(name: .long, help: "UTI for base64 payload or to force type")
    var uti: String?

    @Option(name: .long, help: "Preferred UTI when reading clipboard")
    var prefer: String?

    @Option(name: .shortAndLong, help: "Output path for binary reads ('-' for stdout)")
    var output: String?

    @Option(name: .long, help: "Slot name for save/restore (default: 0)")
    var slot: String?

    @Option(name: .long, help: "Optional plain-text companion when setting binary")
    var alsoText: String?

    @Flag(name: .long, help: "Allow payloads larger than 10 MB")
    var allowLarge = false

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else { preconditionFailure("CommandRuntime must be configured") }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }

    private var configuration: CommandRuntime.Configuration {
        if let runtime { runtime.configuration } else { self.runtimeOptions.makeConfiguration() }
    }

    var jsonOutput: Bool { self.configuration.jsonOutput }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        switch self.action.lowercased() {
        case "get":
            try self.handleGet()
        case "set":
            try self.handleSet()
        case "load":
            try self.handleLoad()
        case "clear":
            self.handleClear()
        case "save":
            try self.handleSave()
        case "restore":
            try self.handleRestore()
        default:
            throw ValidationError("Invalid action: \(self.action)")
        }
    }

    // MARK: - Actions

    private func handleGet() throws {
        let preferType = self.prefer.flatMap { UTType($0) }
        guard let result = try self.services.clipboard.get(prefer: preferType) else {
            throw ValidationError("Clipboard is empty")
        }

        if let output {
            if output == "-" {
                FileHandle.standardOutput.write(result.data)
            } else {
                let url = URL(fileURLWithPath: output)
                try result.data.write(to: url)
            }
        }

        let payload = ClipboardCommandResult(
            action: "get",
            uti: result.utiIdentifier,
            size: result.data.count,
            filePath: output,
            slot: nil,
            textPreview: result.textPreview
        )

        self.output(payload) {
            if let text = String(data: result.data, encoding: .utf8) {
                print(text)
            } else if let output {
                print("📋 Saved \(result.data.count) bytes (\(result.utiIdentifier)) to \(output)")
            } else {
                print(
                    "📋 Clipboard contains \(result.data.count) bytes of \(result.utiIdentifier); use --output to save."
                )
            }
        }
    }

    private func handleSet() throws {
        let request = try self.makeWriteRequest()
        let result = try self.services.clipboard.set(request)
        let payload = ClipboardCommandResult(
            action: "set",
            uti: result.utiIdentifier,
            size: result.data.count,
            filePath: nil,
            slot: nil,
            textPreview: result.textPreview
        )

        self.output(payload) {
            print("✅ Set clipboard (\(result.utiIdentifier), \(result.data.count) bytes)")
        }
    }

    private func handleLoad() throws {
        guard let path = self.filePath ?? self.imagePath else {
            throw ValidationError("load requires --file-path or --image-path")
        }
        let request = try self.makeWriteRequest(overridePath: path)
        let result = try self.services.clipboard.set(request)
        let payload = ClipboardCommandResult(
            action: "load",
            uti: result.utiIdentifier,
            size: result.data.count,
            filePath: path,
            slot: nil,
            textPreview: result.textPreview
        )

        self.output(payload) {
            print("✅ Loaded \(result.data.count) bytes (\(result.utiIdentifier)) from \(path) into clipboard")
        }
    }

    private func handleClear() {
        self.services.clipboard.clear()
        let payload = ClipboardCommandResult(
            action: "clear",
            uti: nil,
            size: nil,
            filePath: nil,
            slot: nil,
            textPreview: nil
        )
        self.output(payload) {
            print("🧹 Cleared clipboard")
        }
    }

    private func handleSave() throws {
        let slotName = self.slot ?? "0"
        try self.services.clipboard.save(slot: slotName)
        let payload = ClipboardCommandResult(
            action: "save",
            uti: nil,
            size: nil,
            filePath: nil,
            slot: slotName,
            textPreview: nil
        )
        self.output(payload) {
            print("💾 Saved clipboard to slot \"\(slotName)\"")
        }
    }

    private func handleRestore() throws {
        let slotName = self.slot ?? "0"
        let result = try self.services.clipboard.restore(slot: slotName)
        let payload = ClipboardCommandResult(
            action: "restore",
            uti: result.utiIdentifier,
            size: result.data.count,
            filePath: nil,
            slot: slotName,
            textPreview: result.textPreview
        )
        self.output(payload) {
            print("♻️  Restored slot \"\(slotName)\" (\(result.utiIdentifier), \(result.data.count) bytes)")
        }
    }

    // MARK: - Helpers

    private func makeWriteRequest(overridePath: String? = nil) throws -> ClipboardWriteRequest {
        if let text {
            return ClipboardWriteRequest(
                representations: [
                    ClipboardRepresentation(utiIdentifier: UTType.plainText.identifier, data: Data(text.utf8)),
                ],
                alsoText: self.alsoText,
                allowLarge: self.allowLarge
            )
        }

        if let path = overridePath ?? self.filePath ?? self.imagePath {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let uti = UTType(filenameExtension: url.pathExtension) ?? .data
            return ClipboardWriteRequest(
                representations: [ClipboardRepresentation(utiIdentifier: uti.identifier, data: data)],
                alsoText: self.alsoText,
                allowLarge: self.allowLarge
            )
        }

        if let b64 = self.dataBase64, let utiId = self.uti {
            guard let data = Data(base64Encoded: b64) else {
                throw ValidationError("data-base64 is not valid base64")
            }
            return ClipboardWriteRequest(
                representations: [ClipboardRepresentation(utiIdentifier: utiId, data: data)],
                alsoText: self.alsoText,
                allowLarge: self.allowLarge
            )
        }

        throw ValidationError("Provide --text, --file-path/--image-path, or --data-base64 with --uti")
    }
}

struct ClipboardCommandResult: Codable {
    let action: String
    let uti: String?
    let size: Int?
    let filePath: String?
    let slot: String?
    let textPreview: String?
}

@MainActor
extension ClipboardCommand: ParsableCommand {}
extension ClipboardCommand: AsyncRuntimeCommand {}

@MainActor
extension ClipboardCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.action = try values.requireOption("action", as: String.self)
        self.text = try values.decodeOption("text", as: String.self)
        self.filePath = try values.decodeOption("file-path", as: String.self)
        self.imagePath = try values.decodeOption("image-path", as: String.self)
        self.dataBase64 = try values.decodeOption("data-base64", as: String.self)
        self.uti = try values.decodeOption("uti", as: String.self)
        self.prefer = try values.decodeOption("prefer", as: String.self)
        self.output = try values.decodeOption("output", as: String.self)
        self.slot = try values.decodeOption("slot", as: String.self)
        self.alsoText = try values.decodeOption("also-text", as: String.self)
        self.allowLarge = values.flag("allow-large")
    }
}
