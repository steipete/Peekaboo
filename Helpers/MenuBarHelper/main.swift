import AppKit
import CoreGraphics
import Foundation

// LSUIElement helper that enumerates menu bar windows via private CGS APIs and prints JSON.
// Running inside AppKit provides the GUI WindowServer connection needed to see third-party extras.

private struct CGSWindowListOption: OptionSet {
    let rawValue: UInt32
    static let onScreen     = CGSWindowListOption(rawValue: 1 << 0)
    static let menuBarItems = CGSWindowListOption(rawValue: 1 << 1)
    static let activeSpace  = CGSWindowListOption(rawValue: 1 << 2)
}

private func loadSymbol<T>(_ name: String, handle: UnsafeMutableRawPointer?) -> T? {
    guard let sym = dlsym(handle, name) else { return nil }
    return unsafeBitCast(sym, to: T.self)
}

private func loadCGSHandle() -> UnsafeMutableRawPointer? {
    let handles = [
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
    ]
    for path in handles {
        if let h = dlopen(path, RTLD_NOW) { return h }
    }
    return nil
}

private func listMenuBarWindows() -> [[String: Any]] {
    guard let handle = loadCGSHandle(),
          let mainConnSym: @convention(c) () -> UInt32 = loadSymbol("CGSMainConnectionID", handle: handle),
          let copySym: @convention(c) (UInt32, Int32, UInt32) -> CFArray? =
            loadSymbol("CGSCopyWindowsWithOptions", handle: handle),
          let getCountSym: @convention(c) (UInt32, UInt32, UnsafeMutablePointer<Int32>) -> Int32 =
            loadSymbol("CGSGetWindowCount", handle: handle),
          let getMenuBarSym: @convention(c) (
            UInt32, UInt32, Int32, UnsafeMutablePointer<CGWindowID>, UnsafeMutablePointer<Int32>) -> Int32 =
            loadSymbol("CGSGetProcessMenuBarWindowList", handle: handle)
    else {
        return []
    }

    let cid = mainConnSym()

    // Process-level list (Ice primary path).
    var total: Int32 = 0
    _ = getCountSym(cid, 0, &total)
    var buf = [CGWindowID](repeating: 0, count: Int(max(total, 32)))
    var out: Int32 = 0
    _ = getMenuBarSym(cid, 0, total, &buf, &out)
    let procIDs = Array(buf.prefix(Int(out)))

    // Copy-with-options (sometimes returns extras).
    let opts: CGSWindowListOption = [.menuBarItems, .onScreen, .activeSpace]
    let copyIDs = (copySym(cid, 0, opts.rawValue) as? [UInt32]) ?? []

    let ids = Array(Set(procIDs + copyIDs))
    guard !ids.isEmpty else { return [] }

    let windowInfo = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    let dictByID: [CGWindowID: [String: Any]] = Dictionary(uniqueKeysWithValues: windowInfo.compactMap { info in
        guard let id = info[kCGWindowNumber as String] as? CGWindowID else { return nil }
        return (id, info)
    })

    return ids.compactMap { id in
        var info = dictByID[id] ?? [:]
        info["CGSWindowID"] = id
        return info
    }
}

// Initialize AppKit to get a GUI connection (LSUIElement).
NSApplication.shared

let windows = listMenuBarWindows()
let payload: [String: Any] = ["windows": windows]
if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
    FileHandle.standardOutput.write(data)
} else {
    fputs("{\"error\":\"serialization_failed\"}", stdout)
}
fflush(stdout)
exit(0)
