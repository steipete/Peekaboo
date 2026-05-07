import CoreGraphics
import Foundation

struct ObservationWindowMetadata {
    let app: ApplicationIdentity?
    let window: WindowIdentity?
    let bounds: CGRect?
    let context: WindowContext
}

enum ObservationWindowMetadataCatalog {
    static func currentWindow(windowID: CGWindowID) -> ObservationWindowMetadata? {
        let windowInfo = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]]
        guard let info = windowInfo?.first else {
            return nil
        }

        return self.metadata(windowID: windowID, windowInfo: info)
    }

    static func metadata(windowID: CGWindowID, windowInfo: [String: Any]) -> ObservationWindowMetadata {
        let title = windowInfo[kCGWindowName as String] as? String ?? ""
        let bounds = self.bounds(from: windowInfo)
        let pid = self.pid(from: windowInfo[kCGWindowOwnerPID as String])
        let appName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let app = pid.map {
            ApplicationIdentity(
                processIdentifier: $0,
                bundleIdentifier: nil,
                name: appName)
        }
        let window = bounds.map {
            WindowIdentity(
                windowID: Int(windowID),
                title: title,
                bounds: $0,
                index: 0)
        }
        let context = WindowContext(
            applicationName: app?.name,
            applicationBundleId: app?.bundleIdentifier,
            applicationProcessId: app?.processIdentifier,
            windowTitle: window?.title,
            windowID: Int(windowID),
            windowBounds: window?.bounds)

        return ObservationWindowMetadata(
            app: app,
            window: window,
            bounds: bounds,
            context: context)
    }

    private static func bounds(from windowInfo: [String: Any]) -> CGRect? {
        guard
            let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
            let x = self.cgFloat(from: boundsDict["X"]),
            let y = self.cgFloat(from: boundsDict["Y"]),
            let width = self.cgFloat(from: boundsDict["Width"]),
            let height = self.cgFloat(from: boundsDict["Height"])
        else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func pid(from value: Any?) -> Int32? {
        if let number = value as? NSNumber {
            return number.int32Value
        }
        if let intValue = value as? Int {
            return Int32(intValue)
        }
        if let int32Value = value as? Int32 {
            return int32Value
        }
        return nil
    }

    private static func cgFloat(from value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(number.doubleValue)
        }
        return value as? CGFloat
    }
}
