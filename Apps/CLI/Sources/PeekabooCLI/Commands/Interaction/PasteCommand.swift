import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation
import UniformTypeIdentifiers

/// Sets clipboard content, pastes (Cmd+V), then restores the prior clipboard.
@available(macOS 14.0, *)
@MainActor
struct PasteCommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    @Argument(help: "Text to paste")
    var text: String?

    @Option(name: .customLong("text"), help: "Text to paste (alternative to positional argument)")
    var textOption: String?

    @Option(name: .long, help: "Path to file to paste (copies file bytes into clipboard first)")
    var filePath: String?

    @Option(name: .long, help: "Path to image to paste (alias of file-path)")
    var imagePath: String?

    @Option(name: .long, help: "Base64 data to paste")
    var dataBase64: String?

    @Option(name: .long, help: "UTI for base64 payload or to force type")
    var uti: String?

    @Option(name: .long, help: "Optional plain-text companion when setting binary")
    var alsoText: String?

    @Flag(name: .long, help: "Allow payloads larger than 10 MB")
    var allowLarge = false

    @Option(name: .customLong("restore-delay-ms"), help: "Delay before restoring the previous clipboard (ms)")
    var restoreDelayMs: Int = 150

    @OptionGroup var target: InteractionTargetOptions
    @OptionGroup var focusOptions: FocusCommandOptions

    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

    private var resolvedText: String? {
        if let primary = self.text, !primary.isEmpty {
            return primary
        }
        return self.textOption
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            try self.target.validate()
            let request = try self.makeWriteRequest()

            try await ensureFocused(
                snapshotId: nil,
                target: self.target,
                options: self.focusOptions,
                services: self.services
            )

            let priorClipboard = try? self.services.clipboard.get(prefer: nil)
            let restoreSlot = "paste-\(UUID().uuidString)"

            if priorClipboard != nil {
                try self.services.clipboard.save(slot: restoreSlot)
            }

            var restoreResult: ClipboardReadResult?
            defer {
                if self.restoreDelayMs > 0 {
                    usleep(useconds_t(self.restoreDelayMs) * 1000)
                }
                if priorClipboard != nil {
                    restoreResult = try? self.services.clipboard.restore(slot: restoreSlot)
                } else {
                    self.services.clipboard.clear()
                }
            }

            let setResult = try self.services.clipboard.set(request)

            try await AutomationServiceBridge.hotkey(
                automation: self.services.automation,
                keys: "cmd,v",
                holdDuration: 50
            )

            let result = PasteResult(
                success: true,
                pastedUti: setResult.utiIdentifier,
                pastedSize: setResult.data.count,
                pastedTextPreview: setResult.textPreview,
                previousClipboardPresent: priorClipboard != nil,
                restoredUti: restoreResult?.utiIdentifier,
                restoredSize: restoreResult?.data.count,
                restoreDelayMs: self.restoreDelayMs
            )

            self.output(result) {
                print("✅ Pasted (Cmd+V) and restored clipboard")
                print("📋 Pasted: \(setResult.utiIdentifier) (\(setResult.data.count) bytes)")
                if priorClipboard != nil {
                    print("♻️  Restored: \(restoreResult?.utiIdentifier ?? "unknown")")
                } else {
                    print("🧹 Restored: cleared (prior clipboard empty)")
                }
            }
        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private func makeWriteRequest() throws -> ClipboardWriteRequest {
        if let text = self.resolvedText {
            let data = Data(text.utf8)
            return ClipboardWriteRequest(
                representations: ClipboardWriteRequest.textRepresentations(from: data),
                alsoText: nil,
                allowLarge: self.allowLarge
            )
        }

        if let path = self.filePath ?? self.imagePath {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let inferred = UTType(filenameExtension: url.pathExtension) ?? .data
            let forced = self.uti.flatMap(UTType.init(_:)) ?? inferred
            return ClipboardWriteRequest(
                representations: [ClipboardRepresentation(utiIdentifier: forced.identifier, data: data)],
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

        throw ValidationError("Provide text, --file-path/--image-path, or --data-base64 with --uti")
    }
}

struct PasteResult: Codable {
    let success: Bool
    let pastedUti: String
    let pastedSize: Int
    let pastedTextPreview: String?
    let previousClipboardPresent: Bool
    let restoredUti: String?
    let restoredSize: Int?
    let restoreDelayMs: Int
}

@MainActor
extension PasteCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "paste",
                abstract: "Set clipboard, paste (Cmd+V), then restore previous clipboard",
                discussion: """
                    This command reduces drift in automation flows by collapsing:
                      1) clipboard set
                      2) Cmd+V paste
                      3) clipboard restore
                    into one operation.

                    EXAMPLES:
                      peekaboo paste \"Hello\" --app TextEdit
                      peekaboo paste --text \"Hello\" --app TextEdit --window-title \"Untitled\"
                      peekaboo paste --data-base64 \"$BASE64\" --uti public.rtf --also-text \"fallback\" --app TextEdit
                      peekaboo paste --file-path /tmp/snippet.png --app Notes
                """,
                showHelpOnEmptyInvocation: true
            )
        }
    }
}

extension PasteCommand: AsyncRuntimeCommand {}
