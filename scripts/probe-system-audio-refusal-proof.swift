// Independent synthetic playback observer for the disabled recording entry point.
import AVFoundation
import CoreAudio
import Darwin
import Foundation

@main
struct RefusalProof {
    static func outputDevice() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr
        else { throw CocoaError(.featureUnsupported) }
        return device
    }

    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw CocoaError(.featureUnsupported) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000),
              let channels = buffer.floatChannelData
        else { throw CocoaError(.featureUnsupported) }
        buffer.frameLength = 48000
        for channel in 0..<2 {
            for frame in 0..<48000 {
                channels[channel][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / 48000) * 0.01)
            }
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        let before = try self.outputDevice()
        try engine.start()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
        defer {
            player.stop()
            engine.stop()
        }
        Thread.sleep(forTimeInterval: 0.2)
        guard let startTime = player.lastRenderTime,
              let startFrame = player.playerTime(forNodeTime: startTime)?.sampleTime
        else { throw CocoaError(.featureUnsupported) }
        var results: [[String: Any]] = []
        for selection in ["system", String(ProcessInfo.processInfo.processIdentifier)] {
            let child = Process()
            child.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
            child.arguments = [selection, "30", root.appendingPathComponent("capture.caf").path]
            let errors = Pipe()
            let output = Pipe()
            child.standardError = errors
            child.standardOutput = output
            try child.run()
            let deadline = Date().addingTimeInterval(5)
            while child.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
            if child.isRunning {
                _ = kill(child.processIdentifier, SIGKILL)
                child.waitUntilExit()
                throw CocoaError(.featureUnsupported)
            }
            child.waitUntilExit()
            guard let diagnostic = String(bytes: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            else { throw CocoaError(.featureUnsupported) }
            let stdout = output.fileHandleForReading.readDataToEndOfFile()
            let artifacts = try FileManager.default.contentsOfDirectory(atPath: root.path)
            guard child.terminationReason == .exit, child.terminationStatus == 1,
                  diagnostic == "Live audio persistence is disabled until continuing host authorization is verified. "
                  + "No tap or output was created.\n", stdout.isEmpty, artifacts.isEmpty
            else { throw CocoaError(.featureUnsupported) }
            results.append([
                "selection": selection == "system" ? "system" : "process",
                "exit_status": child.terminationStatus,
                "diagnostic": diagnostic.trimmingCharacters(in: .newlines),
                "stdout_bytes": stdout.count, "output_directory_entries": artifacts.count,
            ])
        }
        Thread.sleep(forTimeInterval: 0.2)
        guard let endTime = player.lastRenderTime,
              let endFrame = player.playerTime(forNodeTime: endTime)?.sampleTime,
              endFrame > startFrame, player.isPlaying, engine.isRunning,
              try self.outputDevice() == before
        else { throw CocoaError(.featureUnsupported) }
        let result: [String: Any] = [
            "requests": results, "default_output_unchanged": true,
            "synthetic_player_render_frames_advanced": endFrame - startFrame,
            "engine_running_after_requests": engine.isRunning,
            "physical_audibility_verified": false,
        ]
        let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        guard let text = String(bytes: json, encoding: .utf8) else { throw CocoaError(.featureUnsupported) }
        print(text)
    }
}
