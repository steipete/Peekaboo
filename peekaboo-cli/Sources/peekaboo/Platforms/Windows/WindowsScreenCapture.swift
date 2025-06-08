#if os(Windows)
import Foundation
import CoreGraphics
import WinSDK

/// Windows-specific implementation of screen capture using Win32 APIs
class WindowsScreenCapture: ScreenCaptureProtocol {
    
    func captureScreen(displayIndex: Int?) async throws -> [CapturedImage] {
        let displays = try getAvailableDisplays()
        var capturedImages: [CapturedImage] = []
        
        if let displayIndex = displayIndex {
            if displayIndex >= 0 && displayIndex < displays.count {
                let display = displays[displayIndex]
                let image = try await captureSingleDisplay(display)
                capturedImages.append(image)
            } else {
                throw ScreenCaptureError.displayNotFound(displayIndex)
            }
        } else {
            // Capture all displays
            for display in displays {
                let image = try await captureSingleDisplay(display)
                capturedImages.append(image)
            }
        }
        
        return capturedImages
    }
    
    func captureWindow(windowId: UInt32) async throws -> CapturedImage {
        let hwnd = HWND(bitPattern: UInt(windowId))
        guard hwnd != nil else {
            throw ScreenCaptureError.windowNotFound(windowId)
        }
        
        // Get window rectangle
        var rect = RECT()
        guard GetWindowRect(hwnd, &rect) != 0 else {
            throw ScreenCaptureError.windowNotFound(windowId)
        }
        
        let width = rect.right - rect.left
        let height = rect.bottom - rect.top
        
        guard width > 0 && height > 0 else {
            throw ScreenCaptureError.captureFailure("Window has invalid dimensions")
        }
        
        // Get window DC
        guard let windowDC = GetWindowDC(hwnd) else {
            throw ScreenCaptureError.captureFailure("Failed to get window device context")
        }
        defer { ReleaseDC(hwnd, windowDC) }
        
        // Create compatible DC and bitmap
        guard let memoryDC = CreateCompatibleDC(windowDC) else {
            throw ScreenCaptureError.captureFailure("Failed to create compatible device context")
        }
        defer { DeleteDC(memoryDC) }
        
        guard let bitmap = CreateCompatibleBitmap(windowDC, width, height) else {
            throw ScreenCaptureError.captureFailure("Failed to create compatible bitmap")
        }
        defer { DeleteObject(bitmap) }
        
        // Select bitmap into memory DC
        let oldBitmap = SelectObject(memoryDC, bitmap)
        defer { SelectObject(memoryDC, oldBitmap) }
        
        // Copy window content to memory DC
        guard BitBlt(memoryDC, 0, 0, width, height, windowDC, 0, 0, SRCCOPY) != 0 else {
            throw ScreenCaptureError.captureFailure("Failed to copy window content")
        }
        
        // Convert to CGImage
        let cgImage = try createCGImageFromBitmap(bitmap, width: Int(width), height: Int(height))
        
        // Get window title
        let titleLength = GetWindowTextLengthW(hwnd)
        var title = "Untitled"
        if titleLength > 0 {
            let buffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(titleLength + 1))
            defer { buffer.deallocate() }
            if GetWindowTextW(hwnd, buffer, titleLength + 1) > 0 {
                title = String(decodingCString: buffer, as: UTF16.self)
            }
        }
        
        let metadata = CaptureMetadata(
            captureTime: Date(),
            displayIndex: nil,
            windowId: windowId,
            windowTitle: title,
            applicationName: nil, // TODO: Get application name
            bounds: CGRect(x: CGFloat(rect.left), y: CGFloat(rect.top), 
                          width: CGFloat(width), height: CGFloat(height)),
            scaleFactor: 1.0,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        return CapturedImage(image: cgImage, metadata: metadata)
    }
    
    func captureApplication(pid: pid_t, windowIndex: Int?) async throws -> [CapturedImage] {
        // Get all windows for the process
        let windows = try getWindowsForProcess(pid)
        
        if windows.isEmpty {
            throw ScreenCaptureError.captureFailure("No windows found for process \(pid)")
        }
        
        var capturedImages: [CapturedImage] = []
        
        if let windowIndex = windowIndex {
            if windowIndex >= 0 && windowIndex < windows.count {
                let windowId = windows[windowIndex]
                let image = try await captureWindow(windowId: windowId)
                capturedImages.append(image)
            } else {
                throw ScreenCaptureError.captureFailure("Window index \(windowIndex) out of range")
            }
        } else {
            // Capture all windows
            for windowId in windows {
                let image = try await captureWindow(windowId: windowId)
                capturedImages.append(image)
            }
        }
        
        return capturedImages
    }
    
    func getAvailableDisplays() throws -> [DisplayInfo] {
        var displays: [DisplayInfo] = []
        var index = 0
        
        // Enumerate display monitors
        let enumProc: MONITORENUMPROC = { (hMonitor, hdcMonitor, lprcMonitor, dwData) in
            guard let lprcMonitor = lprcMonitor else { return TRUE }
            let rect = lprcMonitor.pointee
            
            var monitorInfo = MONITORINFO()
            monitorInfo.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
            
            if GetMonitorInfoW(hMonitor, &monitorInfo) != 0 {
                let displays = Unmanaged<NSMutableArray>.fromOpaque(UnsafeRawPointer(bitPattern: UInt(dwData))!).takeUnretainedValue()
                
                let bounds = CGRect(
                    x: CGFloat(rect.left),
                    y: CGFloat(rect.top),
                    width: CGFloat(rect.right - rect.left),
                    height: CGFloat(rect.bottom - rect.top)
                )
                
                let workArea = CGRect(
                    x: CGFloat(monitorInfo.rcWork.left),
                    y: CGFloat(monitorInfo.rcWork.top),
                    width: CGFloat(monitorInfo.rcWork.right - monitorInfo.rcWork.left),
                    height: CGFloat(monitorInfo.rcWork.bottom - monitorInfo.rcWork.top)
                )
                
                let isPrimary = (monitorInfo.dwFlags & MONITORINFOF_PRIMARY) != 0
                
                let displayInfo = DisplayInfo(
                    displayId: UInt32(bitPattern: hMonitor),
                    index: displays.count,
                    bounds: bounds,
                    workArea: workArea,
                    scaleFactor: 1.0, // TODO: Get actual DPI scaling
                    isPrimary: isPrimary,
                    name: "Display \(displays.count + 1)",
                    colorSpace: CGColorSpaceCreateDeviceRGB()
                )
                
                displays.add(displayInfo)
            }
            
            return TRUE
        }
        
        let displaysArray = NSMutableArray()
        let context = Unmanaged.passUnretained(displaysArray).toOpaque()
        
        guard EnumDisplayMonitors(nil, nil, enumProc, UInt(bitPattern: context)) != 0 else {
            throw ScreenCaptureError.captureFailure("Failed to enumerate display monitors")
        }
        
        return displaysArray.compactMap { $0 as? DisplayInfo }
    }
    
    func isScreenCaptureSupported() -> Bool {
        return true
    }
    
    func getPreferredImageFormat() -> ImageFormat {
        return .png
    }
    
    // MARK: - Private Helper Methods
    
    private func captureSingleDisplay(_ display: DisplayInfo) async throws -> CapturedImage {
        // Get desktop DC
        guard let desktopDC = GetDC(nil) else {
            throw ScreenCaptureError.captureFailure("Failed to get desktop device context")
        }
        defer { ReleaseDC(nil, desktopDC) }
        
        let width = Int(display.bounds.width)
        let height = Int(display.bounds.height)
        let x = Int(display.bounds.origin.x)
        let y = Int(display.bounds.origin.y)
        
        // Create compatible DC and bitmap
        guard let memoryDC = CreateCompatibleDC(desktopDC) else {
            throw ScreenCaptureError.captureFailure("Failed to create compatible device context")
        }
        defer { DeleteDC(memoryDC) }
        
        guard let bitmap = CreateCompatibleBitmap(desktopDC, Int32(width), Int32(height)) else {
            throw ScreenCaptureError.captureFailure("Failed to create compatible bitmap")
        }
        defer { DeleteObject(bitmap) }
        
        // Select bitmap into memory DC
        let oldBitmap = SelectObject(memoryDC, bitmap)
        defer { SelectObject(memoryDC, oldBitmap) }
        
        // Copy screen content to memory DC
        guard BitBlt(memoryDC, 0, 0, Int32(width), Int32(height), desktopDC, Int32(x), Int32(y), SRCCOPY) != 0 else {
            throw ScreenCaptureError.captureFailure("Failed to copy screen content")
        }
        
        // Convert to CGImage
        let cgImage = try createCGImageFromBitmap(bitmap, width: width, height: height)
        
        let metadata = CaptureMetadata(
            captureTime: Date(),
            displayIndex: display.index,
            windowId: nil,
            windowTitle: nil,
            applicationName: nil,
            bounds: display.bounds,
            scaleFactor: display.scaleFactor,
            colorSpace: cgImage.colorSpace
        )
        
        return CapturedImage(image: cgImage, metadata: metadata)
    }
    
    private func createCGImageFromBitmap(_ bitmap: HBITMAP, width: Int, height: Int) throws -> CGImage {
        // Get bitmap info
        var bitmapInfo = BITMAP()
        guard GetObjectW(bitmap, Int32(MemoryLayout<BITMAP>.size), &bitmapInfo) != 0 else {
            throw ScreenCaptureError.captureFailure("Failed to get bitmap info")
        }
        
        // Create bitmap info header for DIB
        var bmiHeader = BITMAPINFOHEADER()
        bmiHeader.biSize = DWORD(MemoryLayout<BITMAPINFOHEADER>.size)
        bmiHeader.biWidth = LONG(width)
        bmiHeader.biHeight = -LONG(height) // Negative for top-down DIB
        bmiHeader.biPlanes = 1
        bmiHeader.biBitCount = 32
        bmiHeader.biCompression = BI_RGB
        
        // Allocate buffer for pixel data
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = height * bytesPerRow
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        // Get pixel data
        guard let dc = GetDC(nil) else {
            throw ScreenCaptureError.captureFailure("Failed to get device context")
        }
        defer { ReleaseDC(nil, dc) }
        
        guard GetDIBits(dc, bitmap, 0, UINT(height), buffer, 
                       UnsafeMutablePointer<BITMAPINFO>(OpaquePointer(&bmiHeader)), DIB_RGB_COLORS) != 0 else {
            throw ScreenCaptureError.captureFailure("Failed to get bitmap bits")
        }
        
        // Create data provider
        let dataProvider = CGDataProvider(dataInfo: nil, data: buffer, size: bufferSize) { _, _, _ in }
        guard let provider = dataProvider else {
            throw ScreenCaptureError.captureFailure("Failed to create data provider")
        }
        
        // Create CGImage
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: [.byteOrder32Little, .alphaFirst],
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw ScreenCaptureError.captureFailure("Failed to create CGImage")
        }
        
        return cgImage
    }
    
    private func getWindowsForProcess(_ pid: pid_t) throws -> [UInt32] {
        var windows: [UInt32] = []
        
        let enumProc: WNDENUMPROC = { (hwnd, lParam) in
            var processId: DWORD = 0
            GetWindowThreadProcessId(hwnd, &processId)
            
            let targetPid = UInt32(lParam)
            if processId == targetPid {
                // Check if window is visible
                if IsWindowVisible(hwnd) != 0 {
                    let windows = Unmanaged<NSMutableArray>.fromOpaque(UnsafeRawPointer(bitPattern: UInt(lParam))!).takeUnretainedValue()
                    windows.add(UInt32(bitPattern: hwnd) ?? 0)
                }
            }
            
            return TRUE
        }
        
        let windowsArray = NSMutableArray()
        let context = Unmanaged.passUnretained(windowsArray).toOpaque()
        
        EnumWindows(enumProc, UInt(bitPattern: context))
        
        return windowsArray.compactMap { $0 as? UInt32 }
    }
}
#endif

