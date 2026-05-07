import Foundation
import PeekabooFoundation
import UniformTypeIdentifiers

@MainActor
extension ProcessService {
    func executeClipboardCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        guard case let .clipboard(clipboardParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for clipboard command")
        }

        let action = clipboardParams.action.lowercased()
        let slot = clipboardParams.slot ?? "0"

        switch action {
        case "clear":
            self.clipboardService.clear()
            return StepExecutionResult(output: .success("Cleared clipboard."), snapshotId: nil)

        case "save":
            try self.clipboardService.save(slot: slot)
            return StepExecutionResult(output: .success("Saved clipboard to slot \"\(slot)\"."), snapshotId: nil)

        case "restore":
            let result = try self.clipboardService.restore(slot: slot)
            return StepExecutionResult(
                output: .data([
                    "slot": .success(slot),
                    "uti": .success(result.utiIdentifier),
                    "bytes": .success("\(result.data.count)"),
                    "textPreview": .success(result.textPreview),
                ]),
                snapshotId: nil)

        case "get":
            let preferUTI: UTType? = clipboardParams.prefer.flatMap { UTType($0) }
            guard let result = try self.clipboardService.get(prefer: preferUTI) else {
                return StepExecutionResult(output: .success("Clipboard is empty."), snapshotId: nil)
            }

            if let outputPath = clipboardParams.output {
                let resolvedPath = ClipboardPathResolver.filePath(from: outputPath) ?? outputPath
                try result.data.write(to: ClipboardPathResolver.fileURL(from: resolvedPath))
                return StepExecutionResult(
                    output: .data([
                        "output": .success(resolvedPath),
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            return StepExecutionResult(
                output: .data([
                    "uti": .success(result.utiIdentifier),
                    "bytes": .success("\(result.data.count)"),
                    "textPreview": .success(result.textPreview),
                ]),
                snapshotId: nil)

        case "set", "load":
            let allowLarge = clipboardParams.allowLarge ?? false
            let alsoText = clipboardParams.alsoText

            if let text = clipboardParams.text {
                let request = try ClipboardPayloadBuilder.textRequest(
                    text: text,
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            if let filePath = clipboardParams.filePath {
                let resolvedPath = ClipboardPathResolver.filePath(from: filePath) ?? filePath
                let url = ClipboardPathResolver.fileURL(from: resolvedPath)
                let data = try Data(contentsOf: url)
                let uti = clipboardParams.uti
                    ?? UTType(filenameExtension: url.pathExtension)?.identifier
                    ?? UTType.data.identifier
                let request = ClipboardPayloadBuilder.dataRequest(
                    data: data,
                    utiIdentifier: uti,
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "filePath": .success(resolvedPath),
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            if let dataBase64 = clipboardParams.dataBase64, let uti = clipboardParams.uti {
                let request = try ClipboardPayloadBuilder.base64Request(
                    base64: dataBase64,
                    utiIdentifier: uti,
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            throw ClipboardServiceError.writeFailed(
                "Provide text, file-path/image-path, or data-base64+uti to set the clipboard.")

        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Unknown clipboard action: \(action)")
        }
    }
}
