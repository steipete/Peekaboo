import CoreGraphics
import Foundation

// Thin wrappers around private CGS APIs to enumerate menu bar item windows.
// Mirrors Ice’s bridging to reach status item windows hosted by Control Center on macOS 26.

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSCopyWindowsWithOptions")
private func CGSCopyWindowsWithOptions(_ cid: UInt32, _ owner: Int32, _ options: UInt32) -> CFArray?

// Option bits (mirrored from Ice)
private enum CGSWindowListOption: UInt32 {
    case onScreen     = 1 << 0
    case menuBarItems = 1 << 1
    case activeSpace  = 1 << 2
}

/// Return window IDs for menu bar items (status items), optionally filtered to on-screen/active space.
/// Uses private CGS calls; failures should be treated as “no data.”
func cgsMenuBarWindowIDs(onScreen: Bool = false, activeSpace: Bool = false) -> [CGWindowID] {
    let cid = CGSMainConnectionID()
    var opts: CGSWindowListOption = .menuBarItems
    if onScreen { opts.insert(.onScreen) }
    if activeSpace { opts.insert(.activeSpace) }

    guard let raw = CGSCopyWindowsWithOptions(cid, 0, opts.rawValue) as? [UInt32] else {
        return []
    }
    return raw.map { CGWindowID($0) }
}
