import CoreGraphics
import Darwin
import Foundation

// Prototype: compare CGS menu-bar window visibility from a CLI context.
// Run as plain CLI; to test GUI privilege, re-run after wrapping in an LSUIElement app
// or via an inspector helper. Outputs counts from both private APIs and CGWindowList.

struct CGSMenuProbe {
    typealias CGSConnectionID = UInt32
    typealias CGSMainConnectionFunc = @convention(c) () -> CGSConnectionID
    typealias CGSCopyWindowsFunc = @convention(c) (CGSConnectionID, Int32, UInt32) -> CFArray?
    typealias CGSGetProcessMenuBarWindowListFunc = @convention(c) (
        CGSConnectionID, CGSConnectionID, Int32, UnsafeMutablePointer<CGWindowID>, UnsafeMutablePointer<Int32>) -> Int32
    typealias CGSGetWindowCountFunc = @convention(c) (CGSConnectionID, CGSConnectionID, UnsafeMutablePointer<Int32>) -> Int32

    private static func loadSymbol<T>(_ name: String, handle: UnsafeMutableRawPointer?) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    static func run() {
        let handles = [
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        ]
        var chosen: UnsafeMutableRawPointer?
        for h in handles { if let ptr = dlopen(h, RTLD_NOW) { chosen = ptr; break } }
        guard let handle = chosen else { print("could not load CGS symbols"); return }

        guard
            let mainConn: CGSMainConnectionFunc = loadSymbol("CGSMainConnectionID", handle: handle),
            let copyWindows: CGSCopyWindowsFunc = loadSymbol("CGSCopyWindowsWithOptions", handle: handle),
            let getCount: CGSGetWindowCountFunc = loadSymbol("CGSGetWindowCount", handle: handle),
            let getMenuBarList: CGSGetProcessMenuBarWindowListFunc = loadSymbol("CGSGetProcessMenuBarWindowList", handle: handle)
        else { print("missing symbols"); return }

        let cid = mainConn()

        // CGSCopyWindowsWithOptions path
        let optsMenuBar: UInt32 = 1 << 1
        let optsMenuBarOnScreenActive: UInt32 = (1 << 1) | (1 << 0) | (1 << 2)
        let ids1 = (copyWindows(cid, 0, optsMenuBar) as? [UInt32]) ?? []
        let ids2 = (copyWindows(cid, 0, optsMenuBarOnScreenActive) as? [UInt32]) ?? []

        // CGSGetProcessMenuBarWindowList path
        var total: Int32 = 0
        _ = getCount(cid, 0, &total)
        var buf = [CGWindowID](repeating: 0, count: Int(max(total, 32)))
        var out: Int32 = 0
        let result = getMenuBarList(cid, 0, total, &buf, &out)
        let ids3 = Array(buf.prefix(Int(out)))

        // Public CGWindowList fallback
        let cgList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let layer25 = cgList.filter { ($0[kCGWindowLayer as String] as? Int) == 25 }

        print("CGSCopyWindows menuBar: count=\(ids1.count) ids=\(ids1)")
        print("CGSCopyWindows menuBar onScreen+active: count=\(ids2.count) ids=\(ids2)")
        print("CGSGetProcessMenuBarWindowList: result=\(result) count=\(ids3.count) ids=\(ids3)")
        print("CGWindowList layer 25 near menubar: count=\(layer25.count)")
    }
}

CGSMenuProbe.run()
