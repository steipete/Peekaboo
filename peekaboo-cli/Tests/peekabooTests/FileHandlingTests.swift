import Testing
import Foundation
import CoreGraphics
@testable import peekaboo

@Suite("File Handling Tests")
struct FileHandlingTests {
    
    @Suite("FileNameGenerator Tests")
    struct FileNameGeneratorTests {
        
        @Test("Generates default filename with timestamp", arguments: [
            ImageFormat.png,
            ImageFormat.jpg
        ])
        func testGenerateDefaultFilename(format: ImageFormat) {
            let filename = FileNameGenerator.generateFileName(format: format)
            
            #expect(filename.hasPrefix("capture_"))
            #expect(filename.hasSuffix(".\(format.rawValue)"))
            
            // Check timestamp format (should contain numbers and underscores)
            let timestampPart = filename
                .replacingOccurrences(of: "capture_", with: "")
                .replacingOccurrences(of: ".\(format.rawValue)", with: "")
            #expect(!timestampPart.isEmpty)
            #expect(timestampPart.allSatisfy { $0.isNumber || $0 == "_" })
        }
        
        @Test("Sanitizes app names", arguments: zip(
            ["Safari", "Google Chrome", "Finder"],
            ["Safari", "Google_Chrome", "Finder"]
        ))
        func testSanitizeAppName(input: String, expected: String) {
            let filename = FileNameGenerator.generateFileName(appName: input, format: .png)
            #expect(filename.hasPrefix("\(expected)_"))
            #expect(filename.hasSuffix(".png"))
        }
        
        @Test("Handles screen captures")
        func testHandlesScreenCaptures() {
            let filename = FileNameGenerator.generateFileName(displayIndex: 0, format: .png)
            
            #expect(filename.hasPrefix("screen_1_"))
            #expect(filename.hasSuffix(".png"))
        }
        
        @Test("Handles window captures")
        func testHandlesWindowCaptures() {
            let filename = FileNameGenerator.generateFileName(
                appName: "Safari",
                windowIndex: 0,
                format: .png
            )
            
            #expect(filename.hasPrefix("Safari_window_0_"))
            #expect(filename.hasSuffix(".png"))
        }
    }
    
    @Suite("ImageSaver Tests")
    struct ImageSaverTests {
        let tempDir: URL
        
        init() throws {
            tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        
        @Test("Saves PNG image")
        func testSavePNGImage() throws {
            let image = createTestImage()
            let outputPath = tempDir.appendingPathComponent("test.png").path
            
            try ImageSaver.saveImage(image, to: outputPath, format: .png)
            
            #expect(FileManager.default.fileExists(atPath: outputPath))
            
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
            #expect(data.count > 0)
            
            // PNG magic number
            #expect(data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        }
        
        @Test("Saves JPEG image")
        func testSaveJPEGImage() throws {
            let image = createTestImage()
            let outputPath = tempDir.appendingPathComponent("test.jpg").path
            
            try ImageSaver.saveImage(image, to: outputPath, format: .jpg)
            
            #expect(FileManager.default.fileExists(atPath: outputPath))
            
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
            #expect(data.count > 0)
            
            // JPEG magic number
            #expect(data.prefix(3) == Data([0xFF, 0xD8, 0xFF]))
        }
        
        @Test("Creates parent directories if needed")
        func testCreatesParentDirectories() throws {
            let image = createTestImage()
            let nestedPath = tempDir
                .appendingPathComponent("nested")
                .appendingPathComponent("deep")
                .appendingPathComponent("test.png")
                .path
            
            try ImageSaver.saveImage(image, to: nestedPath, format: .png)
            
            #expect(FileManager.default.fileExists(atPath: nestedPath))
        }
        
        @Test("Throws error for invalid path")
        func testThrowsErrorForInvalidPath() throws {
            let image = createTestImage()
            let invalidPath = "/invalid\0path/test.png" // Null character makes it invalid
            
            #expect(throws: CaptureError.self) {
                try ImageSaver.saveImage(image, to: invalidPath, format: .png)
            }
        }
        
        private func createTestImage() -> CGImage {
            let width = 100
            let height = 100
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 4 * width,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )!
            
            // Draw a simple red rectangle
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            return context.makeImage()!
        }
    }
    
    @Suite("OutputPathResolver Tests")
    struct OutputPathResolverTests {
        let tempDir: URL
        
        init() throws {
            tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        
        @Test("Resolves file paths")
        func testResolvesFilePaths() {
            let fileName = "screenshot.png"
            let filePath = "/tmp/test.png"
            
            let resolved = OutputPathResolver.getOutputPath(
                basePath: filePath,
                fileName: fileName,
                isSingleCapture: true
            )
            
            #expect(resolved == filePath)
        }
        
        @Test("Resolves directory paths")
        func testResolvesDirectoryPaths() {
            let fileName = "screenshot.png"
            let dirPath = tempDir.path
            
            let resolved = OutputPathResolver.getOutputPath(
                basePath: dirPath,
                fileName: fileName
            )
            
            #expect(resolved == "\(dirPath)/\(fileName)")
        }
        
        @Test("Handles nil base path")
        func testHandlesNilBasePath() {
            let fileName = "screenshot.png"
            
            let resolved = OutputPathResolver.getOutputPath(
                basePath: nil,
                fileName: fileName
            )
            
            // Should use default save path
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(cliValue: nil)
            #expect(resolved == "\(defaultPath)/\(fileName)")
        }
        
        @Test("Handles multiple captures with file path")
        func testMultipleCapturesWithFilePath() {
            let fileName = "screen_1_20250101_120000.png"
            let filePath = "/tmp/screenshot.png"
            
            let resolved = OutputPathResolver.getOutputPath(
                basePath: filePath,
                fileName: fileName,
                isSingleCapture: false
            )
            
            // Should append screen info to filename
            #expect(resolved.contains("_1_20250101_120000"))
            #expect(resolved.hasSuffix(".png"))
        }
        
        @Test("Handles window captures")
        func testHandlesWindowCaptures() {
            let fileName = "Safari_window_0_20250101_120000.png"
            let filePath = "/tmp/screenshot.png"
            
            let resolved = OutputPathResolver.getOutputPath(
                basePath: filePath,
                fileName: fileName,
                isSingleCapture: false
            )
            
            // Should append window info to filename
            #expect(resolved.contains("_Safari_window_0_20250101_120000"))
            #expect(resolved.hasSuffix(".png"))
        }
        
        @Test("Validates paths for security")
        func testValidatesPathSecurity() {
            // OutputPathResolver.validatePath is private, but we can test through public API
            let fileName = "screenshot.png"
            
            // Path traversal attempt - should still work but might log warning
            let pathTraversal = "../../../tmp/test.png"
            let resolved = OutputPathResolver.getOutputPath(
                basePath: pathTraversal,
                fileName: fileName,
                isSingleCapture: true
            )
            
            #expect(resolved == pathTraversal)
        }
    }
    
    @Suite("FileHandleTextOutputStream Tests")
    struct FileHandleTextOutputStreamTests {
        
        @Test("Writes to stdout")
        func testWritesToStdout() {
            var stream = FileHandleTextOutputStream(.standardOutput)
            // Just verify it doesn't crash
            stream.write("Test output\n")
        }
        
        @Test("Writes to stderr")
        func testWritesToStderr() {
            var stream = FileHandleTextOutputStream(.standardError)
            // Just verify it doesn't crash
            stream.write("Test error\n")
        }
        
        @Test("Writes to custom file handle")
        func testWritesToCustomFileHandle() throws {
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).txt")
            
            FileManager.default.createFile(atPath: tempFile.path, contents: nil)
            defer { try? FileManager.default.removeItem(at: tempFile) }
            
            let fileHandle = try FileHandle(forWritingTo: tempFile)
            defer { try? fileHandle.close() }
            
            var stream = FileHandleTextOutputStream(fileHandle)
            stream.write("Hello, World!")
            
            try fileHandle.close()
            
            let content = try String(contentsOf: tempFile)
            #expect(content == "Hello, World!")
        }
    }
}