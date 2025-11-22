import CoreGraphics
import Foundation
import AppKit
import Darwin

// Dynamic loader mirroring Peekaboo CGS bridge
private struct CGSWindowListOption: OptionSet {
    let rawValue: UInt32
    static let onScreen     = CGSWindowListOption(rawValue: 1 << 0)
    static let menuBarItems = CGSWindowListOption(rawValue: 1 << 1)
    static let activeSpace  = CGSWindowListOption(rawValue: 1 << 2)
}

func loadHandle() -> UnsafeMutableRawPointer? {
    let candidates = [
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
    ]
    for path in candidates {
        if let h = dlopen(path, RTLD_NOW) { return h }
    }
    return nil
}

func cgsMenuBarWindowIDs() -> [UInt32] {
    guard let handle = loadHandle(),
          let mainSym = dlsym(handle, "CGSMainConnectionID"),
          let copySym = dlsym(handle, "CGSCopyWindowsWithOptions") else { return [] }

    typealias MainConn = @convention(c) () -> UInt32
    typealias CopyWins = @convention(c) (UInt32, Int32, UInt32) -> CFArray?
    let mainConnection = unsafeBitCast(mainSym, to: MainConn.self)
    let copyWindows = unsafeBitCast(copySym, to: CopyWins.self)

    let cid = mainConnection()
    let opts: CGSWindowListOption = [.menuBarItems, .onScreen, .activeSpace]
    if let arr = copyWindows(cid, 0, opts.rawValue) as? [UInt32] {
        return arr
    }
    return []
}

func cgsProcessMenuBarIDs() -> [UInt32] {
    guard let handle = loadHandle(),
          let mainSym = dlsym(handle, "CGSMainConnectionID"),
          let countSym = dlsym(handle, "CGSGetWindowCount"),
          let listSym = dlsym(handle, "CGSGetProcessMenuBarWindowList") else { return [] }

    typealias MainConn = @convention(c) () -> UInt32
    typealias GetCount = @convention(c) (UInt32, UInt32, UnsafeMutablePointer<Int32>) -> Int32
    typealias GetList = @convention(c) (UInt32, UInt32, Int32, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<Int32>) -> Int32

    let mainConnection = unsafeBitCast(mainSym, to: MainConn.self)
    let getCount = unsafeBitCast(countSym, to: GetCount.self)
    let getList = unsafeBitCast(listSym, to: GetList.self)

    let cid = mainConnection()
    var total: Int32 = 0
    _ = getCount(cid, 0, &total)
    var buf = [UInt32](repeating: 0, count: Int(max(total, 32)))
    var out: Int32 = 0
    _ = getList(cid, 0, total, &buf, &out)
    return Array(buf.prefix(Int(out)))
}

func cgLayer25Count() -> Int {
    let cgList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return cgList.filter { ($0[kCGWindowLayer as String] as? Int) == 25 }.count
}

@main
struct ProbeApp {
    static func main() {
        NSApplication.shared // ensure AppKit init for LSUIElement context
        let idsCopy = cgsMenuBarWindowIDs()
        let idsProc = cgsProcessMenuBarIDs()
        let layer25 = cgLayer25Count()
        print("CGSCopy menuBar=\(idsCopy.count) ids=\(idsCopy)")
        print("CGSGetProcessMenuBarWindowList=\(idsProc.count) ids=\(idsProc)")
        print("CGWindowList layer25=\(layer25)")
        fflush(stdout)
        exit(0)
    }
}
