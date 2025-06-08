#if os(macOS)
import Foundation
import CoreGraphics
import AppKit

/// macOS implementation of window management using AppKit and Core Graphics
struct macOSWindowManager: WindowManagerProtocol {
    
    func getWindows(for applicationId: String) async throws -> [PlatformWindowInfo] {
        let allWindows = try await getAllWindows()
        return allWindows.filter { $0.applicationId == applicationId }
    }
    
    func getAllWindows() async throws -> [PlatformWindowInfo] {
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        
        var windows: [PlatformWindowInfo] = []
        
        for windowDict in windowList {
            guard let windowNumber = windowDict[kCGWindowNumber as String] as? Int,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let windowTitle = windowDict[kCGWindowName as String] as? String,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            let level = windowDict[kCGWindowLayer as String] as? Int ?? 0
            let ownerPID = windowDict[kCGWindowOwnerPID as String] as? Int ?? 0
            
            // Skip windows with empty titles or very small dimensions
            guard !windowTitle.isEmpty, width > 50, height > 50 else {
                continue
            }
            
            let windowInfo = PlatformWindowInfo(
                id: String(windowNumber),
                title: windowTitle,
                bounds: bounds,
                applicationName: ownerName,
                applicationId: String(ownerPID),
                isVisible: true,
                isMinimized: false,
                level: level
            )
            
            windows.append(windowInfo)
        }
        
        return windows
    }
    
    func getWindow(by windowId: String) async throws -> PlatformWindowInfo? {
        guard let windowNumber = Int(windowId) else {
            return nil
        }
        
        let allWindows = try await getAllWindows()
        return allWindows.first { $0.id == windowId }
    }
    
    static func isSupported() -> Bool {
        return true // macOS always supports window management
    }
}

#endif
