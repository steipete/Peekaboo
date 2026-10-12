// Standalone feasibility probe. Compile with swiftc -swift-version 6 -parse-as-library.
// This does not install or alter Peekaboo's production Bridge.
import AVFoundation
import Darwin
import Foundation

enum ProbeError: LocalizedError {
    case invalid(String)
    case livePersistenceUnavailable

    var errorDescription: String? {
        switch self {
        case let .invalid(message): message
        case .livePersistenceUnavailable:
            "Live audio persistence is disabled until continuing host authorization is verified. "
                + "No tap or output was created."
        }
    }
}

struct CaptureRequest {
    let pid: Int32?
    let seconds: Double
    let output: URL

    init(arguments: [String]) throws {
        guard arguments.count == 3 else {
            throw ProbeError.invalid("Usage: probe-system-audio <system|PID> <seconds: 0.1...60> <new-output.caf>")
        }
        if arguments[0] == "system" {
            self.pid = nil
        } else {
            guard let pid = Int32(arguments[0]), pid > 0 else {
                throw ProbeError.invalid("PID must be a positive Int32; use system for all output.")
            }
            self.pid = pid
        }
        guard let seconds = Double(arguments[1]), seconds.isFinite, (0.1...60).contains(seconds) else {
            throw ProbeError.invalid("Duration must be finite and between 0.1 and 60 seconds.")
        }
        self.seconds = seconds
        self.output = URL(fileURLWithPath: NSString(string: arguments[2]).expandingTildeInPath)
        guard self.output.pathExtension.lowercased() == "caf" else {
            throw ProbeError.invalid("Output must use .caf (lossless native PCM).")
        }
        guard !FileManager.default.fileExists(atPath: self.output.path) else {
            throw ProbeError.invalid("Output already exists; capture never overwrites a file.")
        }
    }
}

/// Synthetic self-test sink only; no native tap or IOProc supplies this object.
final class PCMSink: @unchecked Sendable {
    private var file: AVAudioFile?
    private let format: AVAudioFormat
    private(set) var error: (any Error)?
    private(set) var frames: Int64 = 0
    private(set) var samples: Int64 = 0
    private(set) var nonzeroSamples: Int64 = 0
    private(set) var peak: Double = 0
    private var sumSquares: Double = 0

    init(url: URL, format: AVAudioFormat) throws {
        self.format = format
        var settings = format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        self.file = try AVAudioFile(
            forWriting: url, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
    }

    func consume(_ input: UnsafePointer<AudioBufferList>) {
        guard self.error == nil else { return }
        guard let pcm = AVAudioPCMBuffer(pcmFormat: self.format, bufferListNoCopy: input, deallocator: nil) else {
            self.error = ProbeError.invalid("Core Audio supplied an incompatible PCM buffer.")
            return
        }
        do {
            try self.file?.write(from: pcm)
            self.frames += Int64(pcm.frameLength)
            for buffer in UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)) {
                guard let data = buffer.mData else { continue }
                let values = UnsafeBufferPointer(
                    start: data.assumingMemoryBound(to: Float.self),
                    count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
                for sample in values {
                    let value = Double(sample)
                    guard value.isFinite else {
                        throw ProbeError.invalid("Core Audio supplied non-finite samples.")
                    }
                    self.samples += 1
                    if sample != 0 {
                        self.nonzeroSamples += 1
                    }
                    self.peak = max(self.peak, abs(value))
                    self.sumSquares += value * value
                }
            }
        } catch {
            self.error = error
        }
    }

    var rms: Double {
        self.samples == 0 ? 0 : sqrt(self.sumSquares / Double(self.samples))
    }

    func close() {
        self.file = nil
    }
}

func terminateWithMessage(_ message: String, status: Int32) -> Never {
    // A disconnected reader must not replace our exit status with SIGPIPE.
    _ = signal(SIGPIPE, SIG_IGN)
    // A full stderr pipe must not keep a stalled HAL process alive.
    let flags = fcntl(STDERR_FILENO, F_GETFL)
    if flags >= 0, fcntl(STDERR_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 {
        message.withCString { pointer in
            _ = write(STDERR_FILENO, pointer, strlen(pointer))
        }
    }
    _exit(status)
}

/// No runtime flag or permission grant can enable the removed live capture path.
func refuseLivePersistence(_: CaptureRequest) throws -> Never {
    throw ProbeError.livePersistenceUnavailable
}

@main
struct SystemAudioProbe {
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments == ["--self-test"] {
                try runSelfTests()
                return
            }
            let request = try CaptureRequest(arguments: arguments)
            try refuseLivePersistence(request)
        } catch {
            terminateWithMessage("\(error.localizedDescription)\n", status: 1)
        }
    }
}
