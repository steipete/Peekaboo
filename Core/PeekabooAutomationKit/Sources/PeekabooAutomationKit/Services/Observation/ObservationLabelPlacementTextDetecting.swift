import AppKit

@MainActor
protocol SmartLabelPlacerTextDetecting: AnyObject {
    func scoreRegionForLabelPlacement(_ rect: NSRect, in image: NSImage) -> Float
    func analyzeRegion(_ rect: NSRect, in image: NSImage) -> AcceleratedTextDetector.EdgeDensityResult
}

extension AcceleratedTextDetector: SmartLabelPlacerTextDetecting {}
