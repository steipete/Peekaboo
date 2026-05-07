import CoreGraphics
import Foundation

enum ScreenCaptureImageScaler {
    static func maybeDownscale(
        _ image: CGImage,
        scale: CaptureScalePreference,
        fallbackScale: CGFloat) -> CGImage
    {
        guard scale == .logical1x, fallbackScale > 1 else {
            return image
        }

        let targetSize = CGSize(
            width: CGFloat(image.width) / fallbackScale,
            height: CGFloat(image.height) / fallbackScale)
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width.rounded()),
            height: Int(targetSize.height.rounded()),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue)
        else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        return context.makeImage() ?? image
    }
}
