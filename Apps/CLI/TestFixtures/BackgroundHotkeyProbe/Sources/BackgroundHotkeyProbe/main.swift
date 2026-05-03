import AppKit
import Foundation

let logPath = ProcessInfo.processInfo.environment["PEEKABOO_HOTKEY_PROBE_LOG"]
    ?? "/tmp/peekaboo-background-hotkey-probe-\(ProcessInfo.processInfo.processIdentifier).jsonl"
let readyPath = ProcessInfo.processInfo.environment["PEEKABOO_HOTKEY_PROBE_READY"]

@MainActor
final class EventLogger {
    private let url: URL
    private let encoder = JSONEncoder()

    init(path: String) {
        self.url = URL(fileURLWithPath: path)
        FileManager.default.createFile(atPath: path, contents: nil)
    }

    func record(_ event: NSEvent, phase: String) {
        let payload = EventPayload(
            phase: phase,
            timestamp: Date().timeIntervalSince1970,
            pid: ProcessInfo.processInfo.processIdentifier,
            isActive: NSApp.isActive,
            type: event.type.debugName,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.rawValue,
            characters: event.characters ?? "",
            charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? ""
        )

        guard let data = try? self.encoder.encode(payload),
              let handle = try? FileHandle(forWritingTo: self.url)
        else {
            return
        }

        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        _ = try? handle.write(contentsOf: data + Data("\n".utf8))
    }
}

struct EventPayload: Encodable {
    let phase: String
    let timestamp: TimeInterval
    let pid: Int32
    let isActive: Bool
    let type: String
    let keyCode: UInt16
    let modifierFlags: UInt
    let characters: String
    let charactersIgnoringModifiers: String
}

struct ReadyPayload: Encodable {
    let pid: Int32
    let logPath: String
}

extension NSEvent.EventType {
    var debugName: String {
        switch self {
        case .keyDown:
            "keyDown"
        case .keyUp:
            "keyUp"
        case .flagsChanged:
            "flagsChanged"
        default:
            String(describing: self)
        }
    }
}

let logger = EventLogger(path: logPath)
let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 200, y: 200, width: 420, height: 160),
    styleMask: [.titled, .closable],
    backing: .buffered,
    defer: false
)
window.title = "Peekaboo Background Hotkey Probe"
window.contentView = NSTextField(labelWithString: "Listening for background hotkeys")
window.makeKeyAndOrderFront(nil)

let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
    logger.record(event, phase: "localMonitor")
    return event
}

if let readyPath {
    let ready = ReadyPayload(pid: ProcessInfo.processInfo.processIdentifier, logPath: logPath)
    if let readyData = try? JSONEncoder().encode(ready) {
        try? readyData.write(to: URL(fileURLWithPath: readyPath), options: .atomic)
    }
}

print("pid=\(ProcessInfo.processInfo.processIdentifier)")
print("log=\(logPath)")
fflush(stdout)

_ = monitor
app.run()
