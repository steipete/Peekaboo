import CoreGraphics
import Foundation
import ImageIO
import Vision

struct OCRTextObservation: Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

struct OCRTextResult: Sendable {
    let observations: [OCRTextObservation]
    let imageSize: CGSize
}

enum OCRServiceError: Error {
    case invalidImageData
}

enum OCRService {
    static func recognizeText(in imageData: Data) throws -> OCRTextResult {
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
                boundingBox: observation.boundingBox
            )
        }

        return OCRTextResult(
            observations: observations,
            imageSize: CGSize(width: image.width, height: image.height)
        )
    }
}
