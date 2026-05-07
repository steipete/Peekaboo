import CoreGraphics
import Foundation

enum SmartCaptureImageProcessor {
    static func cgImage(from result: CaptureResult) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: result.imageData as CFData),
              let cgImage = CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent)
        else {
            return nil
        }
        return cgImage
    }

    static func perceptualHash(_ image: CGImage) -> UInt64 {
        guard let resized = resize(image, to: CGSize(width: 9, height: 8)),
              let pixels = grayscalePixels(resized)
        else {
            return 0
        }

        var hash: UInt64 = 0
        for row in 0..<8 {
            for col in 0..<8 {
                let left = pixels[row * 9 + col]
                let right = pixels[row * 9 + col + 1]
                if left > right {
                    hash |= (1 << UInt64(row * 8 + col))
                }
            }
        }
        return hash
    }

    static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    static func resize(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func grayscalePixels(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return nil
        }

        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var grayscale: [UInt8] = []
        grayscale.reserveCapacity(width * height)

        for i in 0..<(width * height) {
            let r = Float(pixels[i * 4])
            let g = Float(pixels[i * 4 + 1])
            let b = Float(pixels[i * 4 + 2])
            grayscale.append(UInt8(0.299 * r + 0.587 * g + 0.114 * b))
        }

        return grayscale
    }
}
