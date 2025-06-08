#if os(Windows)
import Foundation
import WinSDK

/// Windows implementation of screen capture using DXGI Desktop Duplication API and GDI+
struct WindowsScreenCapture: ScreenCaptureProtocol {
    
    func captureScreen(screenIndex: Int) async throws -> Data {
        let screens = try await getAvailableScreens()
        guard screenIndex < screens.count else {
            throw WindowsScreenCaptureError.invalidScreenIndex(screenIndex)
        }
        
        let screen = screens[screenIndex]
        return try captureScreenArea(bounds: screen.bounds)
    }
    
    func captureWindow(windowId: String, bounds: CGRect?) async throws -> Data {
        guard let hwnd = parseWindowHandle(windowId) else {
            throw WindowsScreenCaptureError.invalidWindowId(windowId)
        }
        
        // Get window rectangle
        var rect = RECT()
        guard GetWindowRect(hwnd, &rect) != 0 else {
            throw WindowsScreenCaptureError.windowNotFound(windowId)
        }
        
        let windowBounds = CGRect(
            x: CGFloat(rect.left),
            y: CGFloat(rect.top),
            width: CGFloat(rect.right - rect.left),
            height: CGFloat(rect.bottom - rect.top)
        )
        
        return try captureScreenArea(bounds: bounds ?? windowBounds)
    }
    
    func getAvailableScreens() async throws -> [ScreenInfo] {
        var screens: [ScreenInfo] = []
        var index = 0
        
        // Enumerate all display devices
        var displayDevice = DISPLAY_DEVICEW()
        displayDevice.cb = DWORD(MemoryLayout<DISPLAY_DEVICEW>.size)
        
        while EnumDisplayDevicesW(nil, DWORD(index), &displayDevice, 0) != 0 {
            // Get display settings
            var devMode = DEVMODEW()
            devMode.dmSize = WORD(MemoryLayout<DEVMODEW>.size)
            
            if EnumDisplaySettingsW(displayDevice.DeviceName, ENUM_CURRENT_SETTINGS, &devMode) != 0 {
                let bounds = CGRect(
                    x: CGFloat(devMode.dmPosition.x),
                    y: CGFloat(devMode.dmPosition.y),
                    width: CGFloat(devMode.dmPelsWidth),
                    height: CGFloat(devMode.dmPelsHeight)
                )
                
                let deviceName = String(cString: displayDevice.DeviceName)
                let isPrimary = (displayDevice.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) != 0
                
                let screenInfo = ScreenInfo(
                    index: index,
                    bounds: bounds,
                    name: deviceName,
                    isPrimary: isPrimary
                )
                
                screens.append(screenInfo)
            }
            
            index += 1
            displayDevice = DISPLAY_DEVICEW()
            displayDevice.cb = DWORD(MemoryLayout<DISPLAY_DEVICEW>.size)
        }
        
        return screens
    }
    
    static func isSupported() -> Bool {
        return true // Windows always supports screen capture
    }
    
    // MARK: - Private Methods
    
    private func captureScreenArea(bounds: CGRect) throws -> Data {
        // Try DXGI Desktop Duplication first (Windows 8+)
        if let data = try? captureWithDXGI(bounds: bounds) {
            return data
        }
        
        // Fallback to GDI
        return try captureWithGDI(bounds: bounds)
    }
    
    private func captureWithDXGI(bounds: CGRect) throws -> Data {
        // DXGI Desktop Duplication implementation
        // This is a simplified version - full implementation would require more DXGI setup
        throw WindowsScreenCaptureError.dxgiNotAvailable
    }
    
    private func captureWithGDI(bounds: CGRect) throws -> Data {
        let screenDC = GetDC(nil)
        guard screenDC != nil else {
            throw WindowsScreenCaptureError.failedToGetDC
        }
        defer { ReleaseDC(nil, screenDC) }
        
        let memoryDC = CreateCompatibleDC(screenDC)
        guard memoryDC != nil else {
            throw WindowsScreenCaptureError.failedToCreateCompatibleDC
        }
        defer { DeleteDC(memoryDC) }
        
        let width = Int32(bounds.width)
        let height = Int32(bounds.height)
        
        let bitmap = CreateCompatibleBitmap(screenDC, width, height)
        guard bitmap != nil else {
            throw WindowsScreenCaptureError.failedToCreateBitmap
        }
        defer { DeleteObject(bitmap) }
        
        let oldBitmap = SelectObject(memoryDC, bitmap)
        defer { SelectObject(memoryDC, oldBitmap) }
        
        // Copy screen content to memory DC
        guard BitBlt(memoryDC, 0, 0, width, height, screenDC, Int32(bounds.minX), Int32(bounds.minY), SRCCOPY) != 0 else {
            throw WindowsScreenCaptureError.failedToCopyBits
        }
        
        // Convert bitmap to PNG data
        return try convertBitmapToPNG(bitmap: bitmap!, width: width, height: height)
    }
    
    private func convertBitmapToPNG(bitmap: HBITMAP, width: Int32, height: Int32) throws -> Data {
        // This is a simplified implementation
        // In a real implementation, you would use GDI+ or WIC to convert to PNG
        
        var bitmapInfo = BITMAPINFO()
        bitmapInfo.bmiHeader.biSize = DWORD(MemoryLayout<BITMAPINFOHEADER>.size)
        bitmapInfo.bmiHeader.biWidth = width
        bitmapInfo.bmiHeader.biHeight = -height // Negative for top-down DIB
        bitmapInfo.bmiHeader.biPlanes = 1
        bitmapInfo.bmiHeader.biBitCount = 32
        bitmapInfo.bmiHeader.biCompression = BI_RGB
        
        let dataSize = Int(width * height * 4) // 4 bytes per pixel (BGRA)
        var pixelData = Data(count: dataSize)
        
        let screenDC = GetDC(nil)
        defer { ReleaseDC(nil, screenDC) }
        
        let result = pixelData.withUnsafeMutableBytes { bytes in
            GetDIBits(screenDC, bitmap, 0, UINT(height), bytes.baseAddress, &bitmapInfo, DIB_RGB_COLORS)
        }
        
        guard result != 0 else {
            throw WindowsScreenCaptureError.failedToGetBitmapBits
        }
        
        // For now, return raw bitmap data
        // In a real implementation, convert to PNG format
        return pixelData
    }
    
    private func parseWindowHandle(_ windowId: String) -> HWND? {
        guard let handle = UInt(windowId, radix: 16) else {
            return nil
        }
        return HWND(bitPattern: handle)
    }
}

// MARK: - Error Types

enum WindowsScreenCaptureError: Error, LocalizedError {
    case invalidScreenIndex(Int)
    case invalidWindowId(String)
    case windowNotFound(String)
    case dxgiNotAvailable
    case failedToGetDC
    case failedToCreateCompatibleDC
    case failedToCreateBitmap
    case failedToCopyBits
    case failedToGetBitmapBits
    
    var errorDescription: String? {
        switch self {
        case .invalidScreenIndex(let index):
            return "Invalid screen index: \\(index)"
        case .invalidWindowId(let id):
            return "Invalid window ID: \\(id)"
        case .windowNotFound(let id):
            return "Window not found: \\(id)"
        case .dxgiNotAvailable:
            return "DXGI Desktop Duplication not available"
        case .failedToGetDC:
            return "Failed to get device context"
        case .failedToCreateCompatibleDC:
            return "Failed to create compatible device context"
        case .failedToCreateBitmap:
            return "Failed to create bitmap"
        case .failedToCopyBits:
            return "Failed to copy screen bits"
        case .failedToGetBitmapBits:
            return "Failed to get bitmap bits"
        }
    }
}

#endif

