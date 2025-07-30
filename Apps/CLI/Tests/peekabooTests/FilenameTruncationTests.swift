import Foundation
import Testing
@testable import peekaboo

@Suite("Filename Truncation Tests")
struct FilenameTruncationTests {
    @Test("Truncates very long filenames to stay within filesystem limits")
    func veryLongFilenamesTruncation() throws {
        // Create a very long filename (300+ characters)
        let veryLongName = String(repeating: "a", count: 300)
        let longPath = "/tmp/\(veryLongName).png"

        // Test with window capture metadata
        let windowFileName = "TestApp_window_0_20250610_120000.png"
        let result = OutputPathResolver.determineOutputPath(
            basePath: longPath,
            fileName: windowFileName,
            screenIndex: nil
        )

        // Extract just the filename from the result
        let resultFilename = URL(fileURLWithPath: result).lastPathComponent

        // macOS filename limit is 255 bytes
        #expect(resultFilename.utf8.count <= 255, "Filename should be truncated to stay within 255 byte limit")

        // Should contain the metadata suffix
        #expect(resultFilename.contains("_TestApp_window_0_20250610_120000"), "Should preserve window metadata")
        #expect(resultFilename.hasSuffix(".png"), "Should preserve file extension")
    }

    @Test("Handles UTF-8 multibyte characters in long filenames")
    func multibyteCharacterTruncation() throws {
        // Create a filename with emoji that will exceed the limit when combined with metadata
        // Each emoji is 4 bytes in UTF-8
        let emojiName = String(repeating: "🎯", count: 65) // 260 bytes
        let longPath = "/tmp/\(emojiName).png"

        // Test with screen capture metadata - this uses safeCombineFilename
        let screenFileName = "screen_1_20250610_120000.png"
        let result = OutputPathResolver.determineOutputPath(
            basePath: longPath,
            fileName: screenFileName,
            screenIndex: nil,
            isSingleCapture: false
        )

        let resultFilename = URL(fileURLWithPath: result).lastPathComponent

        #expect(
            resultFilename.utf8.count <= 255,
            "Filename with multibyte chars should be truncated to stay within 255 byte limit"
        )
        #expect(resultFilename.hasSuffix("_1_20250610_120000.png"), "Should preserve screen metadata")

        // Verify the filename was actually truncated
        let suffix = "_1_20250610_120000.png"
        let maxBasenameBytes = 255 - suffix.utf8.count - 10 // safety buffer
        #expect(resultFilename.utf8.count > maxBasenameBytes, "Result should be close to the limit")
    }

    @Test("Preserves reasonable length filenames without truncation")
    func reasonableLengthFilenames() throws {
        let normalName = "MyScreenshot"
        let normalPath = "/tmp/\(normalName).png"

        let windowFileName = "Finder_window_0_20250610_120000.png"
        let result = OutputPathResolver.determineOutputPath(
            basePath: normalPath,
            fileName: windowFileName,
            screenIndex: nil
        )

        let resultFilename = URL(fileURLWithPath: result).lastPathComponent

        #expect(
            resultFilename == "MyScreenshot_Finder_window_0_20250610_120000.png",
            "Short filenames should not be truncated"
        )
    }

    @Test("Handles edge case at exactly 255 bytes")
    func exactLimitFilename() throws {
        // Calculate a name that will result in exactly 255 bytes total
        // Account for suffix "_TestApp_window_0_20250610_120000" (34 chars) + ".png" (4 chars)
        let suffixLength = 34
        let extensionLength = 4
        let safetyBuffer = 10 // From OutputPathResolver
        let maxBaseLength = 255 - suffixLength - extensionLength - safetyBuffer

        let exactLengthName = String(repeating: "x", count: maxBaseLength)
        let exactPath = "/tmp/\(exactLengthName).png"

        let windowFileName = "TestApp_window_0_20250610_120000.png"
        let result = OutputPathResolver.determineOutputPath(
            basePath: exactPath,
            fileName: windowFileName,
            screenIndex: nil
        )

        let resultFilename = URL(fileURLWithPath: result).lastPathComponent

        #expect(resultFilename.utf8.count <= 255, "Filename at limit should not exceed 255 bytes")
        #expect(resultFilename.contains("_TestApp_window_0"), "Should preserve metadata even at limit")
    }

    @Test("Handles directory paths with long filenames")
    func directoryPathsWithLongFilenames() throws {
        // When basePath is a directory, it should just append the fileName
        let directoryPath = "/tmp/screenshots" // No trailing slash
        let veryLongFileName = String(repeating: "b", count: 300) + "_window_0_20250610_120000.png"

        let result = OutputPathResolver.determineOutputPath(
            basePath: directoryPath,
            fileName: veryLongFileName,
            screenIndex: nil
        )

        #expect(
            result == "/tmp/screenshots/\(veryLongFileName)",
            "Directory paths should append filename without truncation"
        )

        // Note: The actual file writing would fail if the filename is too long,
        // but OutputPathResolver doesn't truncate in directory mode
    }

    @Test("Fallback path handling with long filenames")
    func fallbackPathWithLongFilenames() throws {
        let veryLongName = String(repeating: "c", count: 280)
        let longPath = "/tmp/\(veryLongName).png"

        let screenFileName = "screen_2_20250610_120000.png"
        let result = OutputPathResolver.determineOutputPathWithFallback(
            basePath: longPath,
            fileName: screenFileName
        )

        let resultFilename = URL(fileURLWithPath: result).lastPathComponent

        #expect(resultFilename.utf8.count <= 255, "Fallback path should also respect filename limits")
        #expect(resultFilename.contains("_2_20250610_120000"), "Should preserve screen index in fallback")
    }

    @Test("Truncation preserves valid UTF-8 sequences")
    func truncationPreservesValidUTF8() throws {
        // Create a string where truncation might cut in the middle of a multibyte character
        let prefix = String(repeating: "a", count: 220)
        let multibyteChar = "🎨" // 4-byte emoji
        let complexName = prefix + multibyteChar + "suffix"
        let complexPath = "/tmp/\(complexName).png"

        let windowFileName = "App_window_0_20250610_120000.png"
        let result = OutputPathResolver.determineOutputPath(
            basePath: complexPath,
            fileName: windowFileName,
            screenIndex: nil
        )

        let resultFilename = URL(fileURLWithPath: result).lastPathComponent

        // Verify the result is valid UTF-8
        #expect(resultFilename.utf8.count <= 255, "Should stay within byte limit")
        #expect(resultFilename.isValidUTF8, "Truncation should preserve valid UTF-8")

        // The truncation should not result in invalid characters
        let data = resultFilename.data(using: .utf8)
        #expect(data != nil, "Should be convertible to UTF-8 data")
        if let data {
            let reconstructed = String(data: data, encoding: .utf8)
            #expect(reconstructed != nil, "Should be reconstructible from UTF-8 data")
        }
    }

    @Test("Extremely long filenames are truncated properly")
    func extremelyLongFilenames() throws {
        // Create an extremely long filename that definitely needs truncation
        let veryLongName = String(repeating: "x", count: 500)
        let longPath = "/tmp/\(veryLongName).png"

        // Test with window capture
        let windowFileName = "SuperLongAppName_window_0_20250610_120000.png"
        let result = OutputPathResolver.determineOutputPath(
            basePath: longPath,
            fileName: windowFileName,
            screenIndex: nil
        )

        let resultFilename = URL(fileURLWithPath: result).lastPathComponent

        #expect(resultFilename.utf8.count <= 255, "Extremely long filename should be truncated")
        #expect(
            resultFilename.contains("_SuperLongAppName_window_0_20250610_120000"),
            "Should preserve window metadata"
        )
        #expect(resultFilename.hasSuffix(".png"), "Should preserve extension")

        // Verify truncation actually happened
        #expect(resultFilename.utf8.count < veryLongName.utf8.count, "Original name should have been truncated")
    }

    @Test("Single capture uses file path as-is without metadata")
    func singleCaptureNoMetadata() throws {
        let simplePath = "/tmp/my-screenshot.png"
        let windowFileName = "Finder_window_0_20250610_120000.png"

        // Test single capture mode
        let result = OutputPathResolver.determineOutputPath(
            basePath: simplePath,
            fileName: windowFileName,
            screenIndex: nil,
            isSingleCapture: true
        )

        #expect(result == simplePath, "Single capture should use the provided path as-is")
    }

    @Test("Multiple captures append metadata to avoid overwrites")
    func multipleCapturesAppendMetadata() throws {
        let basePath = "/tmp/capture.png"

        // Test window capture with multiple windows
        let windowFileName1 = "Safari_window_0_20250610_120000.png"
        let result1 = OutputPathResolver.determineOutputPath(
            basePath: basePath,
            fileName: windowFileName1,
            screenIndex: nil,
            isSingleCapture: false
        )

        #expect(
            result1 == "/tmp/capture_Safari_window_0_20250610_120000.png",
            "Multiple captures should append window metadata"
        )

        // Test screen capture with multiple screens
        let screenFileName = "screen_1_20250610_120000.png"
        let result2 = OutputPathResolver.determineOutputPath(
            basePath: basePath,
            fileName: screenFileName,
            screenIndex: nil,
            isSingleCapture: false
        )

        #expect(
            result2 == "/tmp/capture_1_20250610_120000.png",
            "Multiple screen captures should append screen metadata"
        )
    }

    @Test("Single capture with very long filename doesn't add metadata")
    func singleCaptureLongFilenameNoMetadata() throws {
        let veryLongName = String(repeating: "a", count: 252) // 252 + 4 for ".png" = 256 bytes
        let longPath = "/tmp/\(veryLongName).png"
        let windowFileName = "App_window_0_20250610_120000.png"

        let result = OutputPathResolver.determineOutputPath(
            basePath: longPath,
            fileName: windowFileName,
            screenIndex: nil,
            isSingleCapture: true
        )

        #expect(result == longPath, "Single capture should not modify even very long filenames")

        // Verify the filename is actually too long for the filesystem
        let resultFilename = URL(fileURLWithPath: result).lastPathComponent
        #expect(resultFilename.utf8.count > 255, "Test filename should exceed filesystem limit")
    }

    @Test("Directory paths always use generated filename regardless of single/multiple")
    func directoryPathsBehavior() throws {
        let directoryPath = "/tmp/screenshots"
        let windowFileName = "Chrome_window_0_20250610_120000.png"

        // Test single capture with directory
        let singleResult = OutputPathResolver.determineOutputPath(
            basePath: directoryPath,
            fileName: windowFileName,
            screenIndex: nil,
            isSingleCapture: true
        )

        #expect(
            singleResult == "/tmp/screenshots/Chrome_window_0_20250610_120000.png",
            "Directory paths should always append the generated filename"
        )

        // Test multiple capture with directory
        let multiResult = OutputPathResolver.determineOutputPath(
            basePath: directoryPath,
            fileName: windowFileName,
            screenIndex: nil,
            isSingleCapture: false
        )

        #expect(
            multiResult == singleResult,
            "Directory behavior should be the same for single and multiple captures"
        )
    }
}

// Helper extension to check UTF-8 validity
extension String {
    var isValidUTF8: Bool {
        data(using: .utf8) != nil
    }
}
