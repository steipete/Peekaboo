import XCTest
@testable import peekaboo

final class PlatformFactoryTests: XCTestCase {
    
    func testFactoryCreatesCorrectPlatformImplementations() {
        let factory = PlatformFactory()
        
        // Test that factory creates non-nil instances
        XCTAssertNotNil(factory.createScreenCapture())
        XCTAssertNotNil(factory.createApplicationFinder())
        XCTAssertNotNil(factory.createWindowManager())
        XCTAssertNotNil(factory.createPermissionChecker())
        
        #if os(macOS)
        // Test macOS-specific implementations
        XCTAssertTrue(factory.createScreenCapture() is macOSScreenCapture)
        XCTAssertTrue(factory.createApplicationFinder() is macOSApplicationFinder)
        XCTAssertTrue(factory.createWindowManager() is macOSWindowManager)
        XCTAssertTrue(factory.createPermissionChecker() is macOSPermissionChecker)
        
        #elseif os(Windows)
        // Test Windows-specific implementations
        XCTAssertTrue(factory.createScreenCapture() is WindowsScreenCapture)
        XCTAssertTrue(factory.createApplicationFinder() is WindowsApplicationFinder)
        XCTAssertTrue(factory.createWindowManager() is WindowsWindowManager)
        XCTAssertTrue(factory.createPermissionChecker() is WindowsPermissionChecker)
        
        #elseif os(Linux)
        // Test Linux-specific implementations
        XCTAssertTrue(factory.createScreenCapture() is LinuxScreenCapture)
        XCTAssertTrue(factory.createApplicationFinder() is LinuxApplicationFinder)
        XCTAssertTrue(factory.createWindowManager() is LinuxWindowManager)
        XCTAssertTrue(factory.createPermissionChecker() is LinuxPermissionChecker)
        #endif
    }
    
    func testImageFormatProperties() {
        // Test PNG format
        let png = ImageFormat.png
        XCTAssertEqual(png.mimeType, "image/png")
        XCTAssertEqual(png.fileExtension, "png")
        XCTAssertEqual(png.coreGraphicsType, "public.png")
        
        // Test JPEG format
        let jpeg = ImageFormat.jpeg
        XCTAssertEqual(jpeg.mimeType, "image/jpeg")
        XCTAssertEqual(jpeg.fileExtension, "jpeg")
        XCTAssertEqual(jpeg.coreGraphicsType, "public.jpeg")
        
        // Test JPG format (should normalize to jpeg)
        let jpg = ImageFormat.jpg
        XCTAssertEqual(jpg.mimeType, "image/jpeg")
        XCTAssertEqual(jpg.fileExtension, "jpeg") // Should normalize
        XCTAssertEqual(jpg.coreGraphicsType, "public.jpeg")
        
        // Test BMP format
        let bmp = ImageFormat.bmp
        XCTAssertEqual(bmp.mimeType, "image/bmp")
        XCTAssertEqual(bmp.fileExtension, "bmp")
        XCTAssertEqual(bmp.coreGraphicsType, "public.bmp")
        
        // Test TIFF format
        let tiff = ImageFormat.tiff
        XCTAssertEqual(tiff.mimeType, "image/tiff")
        XCTAssertEqual(tiff.fileExtension, "tiff")
        XCTAssertEqual(tiff.coreGraphicsType, "public.tiff")
    }
    
    #if os(macOS)
    func testMacOSUTTypes() {
        import UniformTypeIdentifiers
        
        XCTAssertEqual(ImageFormat.png.utType, .png)
        XCTAssertEqual(ImageFormat.jpeg.utType, .jpeg)
        XCTAssertEqual(ImageFormat.jpg.utType, .jpeg)
        XCTAssertEqual(ImageFormat.bmp.utType, .bmp)
        XCTAssertEqual(ImageFormat.tiff.utType, .tiff)
    }
    #endif
    
    func testImageFormatCaseIterable() {
        let allFormats = ImageFormat.allCases
        XCTAssertEqual(allFormats.count, 5)
        XCTAssertTrue(allFormats.contains(.png))
        XCTAssertTrue(allFormats.contains(.jpeg))
        XCTAssertTrue(allFormats.contains(.jpg))
        XCTAssertTrue(allFormats.contains(.bmp))
        XCTAssertTrue(allFormats.contains(.tiff))
    }
    
    func testScreenCaptureErrorDescriptions() {
        let errors: [ScreenCaptureError] = [
            .notSupported,
            .permissionDenied,
            .displayNotFound(1),
            .windowNotFound(123),
            .captureFailure("test reason"),
            .invalidConfiguration,
            .systemError(NSError(domain: "test", code: 1, userInfo: nil))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testCapturedImageStructure() {
        // Create a test CGImage (1x1 pixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let cgImage = context.makeImage()!
        
        let metadata = CaptureMetadata(
            captureTime: Date(),
            displayIndex: 0,
            windowId: nil,
            windowTitle: nil,
            applicationName: nil,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            scaleFactor: 1.0,
            colorSpace: colorSpace
        )
        
        let capturedImage = CapturedImage(image: cgImage, metadata: metadata)
        
        XCTAssertEqual(capturedImage.image.width, 1)
        XCTAssertEqual(capturedImage.image.height, 1)
        XCTAssertEqual(capturedImage.metadata.displayIndex, 0)
        XCTAssertEqual(capturedImage.metadata.scaleFactor, 1.0)
    }
    
    func testDisplayInfoStructure() {
        let displayInfo = DisplayInfo(
            displayId: 1,
            index: 0,
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            workArea: CGRect(x: 0, y: 25, width: 1920, height: 1055),
            scaleFactor: 2.0,
            isPrimary: true,
            name: "Test Display",
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        XCTAssertEqual(displayInfo.displayId, 1)
        XCTAssertEqual(displayInfo.index, 0)
        XCTAssertEqual(displayInfo.bounds.width, 1920)
        XCTAssertEqual(displayInfo.bounds.height, 1080)
        XCTAssertEqual(displayInfo.scaleFactor, 2.0)
        XCTAssertTrue(displayInfo.isPrimary)
        XCTAssertEqual(displayInfo.name, "Test Display")
    }
}

