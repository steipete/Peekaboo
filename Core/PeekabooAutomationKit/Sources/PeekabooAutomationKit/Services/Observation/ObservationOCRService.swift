import CoreGraphics
import Foundation
import ImageIO
import PeekabooFoundation
import Vision

public struct OCRTextObservation: Sendable, Codable, Equatable {
    public let text: String
    public let confidence: Float
    public let boundingBox: CGRect

    public init(text: String, confidence: Float, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

public struct OCRTextResult: Sendable, Codable, Equatable {
    public let observations: [OCRTextObservation]
    public let imageSize: CGSize

    public init(observations: [OCRTextObservation], imageSize: CGSize) {
        self.observations = observations
        self.imageSize = imageSize
    }
}

public enum OCRServiceError: Error, Equatable {
    case invalidImageData
}

@MainActor
public protocol OCRRecognizing: Sendable {
    func recognizeText(in imageData: Data) throws -> OCRTextResult
}

public struct OCRService: OCRRecognizing {
    public init() {}

    public func recognizeText(in imageData: Data) throws -> OCRTextResult {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OCRServiceError.invalidImageData
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = (request.results ?? []).compactMap { observation -> OCRTextObservation? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return OCRTextObservation(
                text: text,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox)
        }

        return OCRTextResult(
            observations: observations,
            imageSize: CGSize(width: image.width, height: image.height))
    }
}

public enum ObservationOCRMapper {
    public static func matches(_ result: OCRTextResult, hints: [String]) -> Bool {
        guard !hints.isEmpty else { return !result.observations.isEmpty }
        let text = result.observations.map(\.text).joined(separator: " ").lowercased()
        return hints.contains { hint in
            text.contains(hint.lowercased())
        }
    }

    public static func elements(
        from result: OCRTextResult,
        windowBounds: CGRect,
        minConfidence: Float = 0.3,
        idPrefix: String = "ocr") -> [DetectedElement]
    {
        var elements: [DetectedElement] = []
        var index = 1

        for observation in result.observations where observation.confidence >= minConfidence {
            let rect = self.screenRect(
                from: observation.boundingBox,
                imageSize: result.imageSize,
                windowBounds: windowBounds)

            guard rect.width > 2, rect.height > 2 else { continue }

            let attributes = [
                "description": "ocr",
                "confidence": String(format: "%.2f", observation.confidence),
            ]

            elements.append(
                DetectedElement(
                    id: "\(idPrefix)_\(index)",
                    type: .staticText,
                    label: observation.text,
                    value: nil,
                    bounds: rect,
                    isEnabled: true,
                    isSelected: nil,
                    attributes: attributes))
            index += 1
        }

        return elements
    }

    public static func merge(
        ocrElements: [DetectedElement],
        into detectionResult: ElementDetectionResult,
        methodSuffix: String = "+OCR") -> ElementDetectionResult
    {
        guard !ocrElements.isEmpty else { return detectionResult }

        let elements = detectionResult.elements
        let mergedElements = DetectedElements(
            buttons: elements.buttons,
            textFields: elements.textFields,
            links: elements.links,
            images: elements.images,
            groups: elements.groups,
            sliders: elements.sliders,
            checkboxes: elements.checkboxes,
            menus: elements.menus,
            other: elements.other + ocrElements)
        let metadata = detectionResult.metadata
        let method = metadata.method.localizedCaseInsensitiveContains("ocr")
            ? metadata.method
            : "\(metadata.method)\(methodSuffix)"

        return ElementDetectionResult(
            snapshotId: detectionResult.snapshotId,
            screenshotPath: detectionResult.screenshotPath,
            elements: mergedElements,
            metadata: DetectionMetadata(
                detectionTime: metadata.detectionTime,
                elementCount: mergedElements.all.count,
                method: method,
                warnings: metadata.warnings,
                windowContext: metadata.windowContext,
                isDialog: metadata.isDialog,
                truncationInfo: metadata.truncationInfo))
    }

    public static func detectionResult(
        from ocrResult: OCRTextResult,
        snapshotID: String?,
        screenshotPath: String,
        windowContext: WindowContext?,
        detectionTime: TimeInterval,
        minConfidence: Float = 0.3) -> ElementDetectionResult
    {
        let windowBounds = windowContext?.windowBounds ?? CGRect(
            origin: .zero,
            size: ocrResult.imageSize)
        let elements = self.elements(
            from: ocrResult,
            windowBounds: windowBounds,
            minConfidence: minConfidence)
        let grouped = DetectedElements(other: elements)
        return ElementDetectionResult(
            snapshotId: snapshotID ?? "ocr-\(UUID().uuidString)",
            screenshotPath: screenshotPath,
            elements: grouped,
            metadata: DetectionMetadata(
                detectionTime: detectionTime,
                elementCount: elements.count,
                method: "OCR",
                warnings: elements.isEmpty ? ["OCR produced no elements"] : [],
                windowContext: windowContext,
                isDialog: false))
    }

    private static func screenRect(
        from normalizedBox: CGRect,
        imageSize: CGSize,
        windowBounds: CGRect) -> CGRect
    {
        let width = normalizedBox.width * imageSize.width
        let height = normalizedBox.height * imageSize.height
        let x = normalizedBox.origin.x * imageSize.width
        let y = (1.0 - normalizedBox.origin.y - normalizedBox.height) * imageSize.height
        return CGRect(
            x: windowBounds.origin.x + x,
            y: windowBounds.origin.y + y,
            width: width,
            height: height)
    }
}
