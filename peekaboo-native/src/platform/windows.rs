use crate::traits::{Platform, ScreenCapture, WindowManager, ApplicationManager, PermissionManager};
use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{ApplicationInfo, WindowData, ImageFormat, WindowBounds};
use std::ffi::OsString;
use std::os::windows::ffi::OsStringExt;

#[cfg(target_os = "windows")]
use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Gdi::*,
    Win32::System::ProcessStatus::*,
    Win32::System::Threading::*,
    Win32::UI::WindowsAndMessaging::*,
    Win32::System::Diagnostics::ToolHelp::*,
};

pub struct WindowsPlatform {
    initialized: bool,
}

impl WindowsPlatform {
    pub fn new() -> PeekabooResult<Self> {
        Ok(Self {
            initialized: false,
        })
    }
}

#[cfg(target_os = "windows")]
impl ScreenCapture for WindowsPlatform {
    fn capture_display(&self, display_index: usize, output_path: &str, format: ImageFormat) -> PeekabooResult<()> {
        unsafe {
            // Get desktop window
            let desktop_hwnd = GetDesktopWindow();
            let desktop_dc = GetDC(desktop_hwnd);
            
            if desktop_dc.is_invalid() {
                return Err(PeekabooError::CaptureCreationFailed("Failed to get desktop DC".to_string()));
            }
            
            // Get screen dimensions
            let screen_width = GetSystemMetrics(SM_CXSCREEN);
            let screen_height = GetSystemMetrics(SM_CYSCREEN);
            
            // Create compatible DC and bitmap
            let mem_dc = CreateCompatibleDC(desktop_dc);
            let bitmap = CreateCompatibleBitmap(desktop_dc, screen_width, screen_height);
            
            if mem_dc.is_invalid() || bitmap.is_invalid() {
                ReleaseDC(desktop_hwnd, desktop_dc);
                return Err(PeekabooError::CaptureCreationFailed("Failed to create compatible DC/bitmap".to_string()));
            }
            
            // Select bitmap into memory DC
            let old_bitmap = SelectObject(mem_dc, bitmap);
            
            // Copy screen to memory DC
            let result = BitBlt(
                mem_dc,
                0, 0,
                screen_width, screen_height,
                desktop_dc,
                0, 0,
                SRCCOPY,
            );
            
            if !result.as_bool() {
                SelectObject(mem_dc, old_bitmap);
                DeleteObject(bitmap);
                DeleteDC(mem_dc);
                ReleaseDC(desktop_hwnd, desktop_dc);
                return Err(PeekabooError::CaptureCreationFailed("Failed to copy screen".to_string()));
            }
            
            // Save bitmap to file
            let save_result = save_bitmap_to_file(bitmap, output_path, format);
            
            // Cleanup
            SelectObject(mem_dc, old_bitmap);
            DeleteObject(bitmap);
            DeleteDC(mem_dc);
            ReleaseDC(desktop_hwnd, desktop_dc);
            
            save_result
        }
    }
    
    fn capture_all_displays(&self, base_path: Option<&str>, format: ImageFormat) -> PeekabooResult<Vec<String>> {
        // For Windows, we'll capture the primary display
        let output_path = generate_output_path(base_path, 0, &format);
        self.capture_display(0, &output_path, format)?;
        Ok(vec![output_path])
    }
    
    fn capture_window(&self, window: &WindowData, output_path: &str, format: ImageFormat) -> PeekabooResult<()> {
        unsafe {
            let hwnd = HWND(window.window_id as isize);
            
            // Get window DC
            let window_dc = GetDC(hwnd);
            if window_dc.is_invalid() {
                return Err(PeekabooError::WindowCaptureFailed("Failed to get window DC".to_string()));
            }
            
            // Get window dimensions
            let mut rect = RECT::default();
            if !GetClientRect(hwnd, &mut rect).as_bool() {
                ReleaseDC(hwnd, window_dc);
                return Err(PeekabooError::WindowCaptureFailed("Failed to get window rect".to_string()));
            }
            
            let width = rect.right - rect.left;
            let height = rect.bottom - rect.top;
            
            // Create compatible DC and bitmap
            let mem_dc = CreateCompatibleDC(window_dc);
            let bitmap = CreateCompatibleBitmap(window_dc, width, height);
            
            if mem_dc.is_invalid() || bitmap.is_invalid() {
                ReleaseDC(hwnd, window_dc);
                return Err(PeekabooError::WindowCaptureFailed("Failed to create compatible DC/bitmap".to_string()));
            }
            
            // Select bitmap into memory DC
            let old_bitmap = SelectObject(mem_dc, bitmap);
            
            // Copy window to memory DC
            let result = BitBlt(
                mem_dc,
                0, 0,
                width, height,
                window_dc,
                0, 0,
                SRCCOPY,
            );
            
            if !result.as_bool() {
                SelectObject(mem_dc, old_bitmap);
                DeleteObject(bitmap);
                DeleteDC(mem_dc);
                ReleaseDC(hwnd, window_dc);
                return Err(PeekabooError::WindowCaptureFailed("Failed to copy window".to_string()));
            }
            
            // Save bitmap to file
            let save_result = save_bitmap_to_file(bitmap, output_path, format);
            
            // Cleanup
            SelectObject(mem_dc, old_bitmap);
            DeleteObject(bitmap);
            DeleteDC(mem_dc);
            ReleaseDC(hwnd, window_dc);
            
            save_result
        }
    }
    
    fn get_display_count(&self) -> PeekabooResult<usize> {
        unsafe {
            let count = GetSystemMetrics(SM_CMONITORS) as usize;
            Ok(count.max(1))
        }
    }
}

#[cfg(target_os = "windows")]
impl WindowManager for WindowsPlatform {
    fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>> {
        let mut windows = Vec::new();
        let mut context = EnumWindowsContext {
            target_pid: pid as u32,
            windows: &mut windows,
            window_index: 0,
        };
        
        unsafe {
            EnumWindows(
                Some(enum_windows_proc),
                LPARAM(&mut context as *mut _ as isize),
            );
        }
        
        Ok(windows)
    }
    
    fn find_window_by_title(&self, pid: i32, title_substring: &str) -> PeekabooResult<WindowData> {
        let windows = self.get_windows_for_app(pid)?;
        windows.into_iter()
            .find(|w| w.title.contains(title_substring))
            .ok_or_else(|| PeekabooError::WindowNotFound)
    }
    
    fn get_window_by_index(&self, pid: i32, index: i32) -> PeekabooResult<WindowData> {
        let windows = self.get_windows_for_app(pid)?;
        windows.into_iter()
            .nth(index as usize)
            .ok_or_else(|| PeekabooError::InvalidWindowIndex(index))
    }
    
    fn activate_window(&self, window: &WindowData) -> PeekabooResult<()> {
        unsafe {
            let hwnd = HWND(window.window_id as isize);
            
            // Bring window to foreground
            if !SetForegroundWindow(hwnd).as_bool() {
                return Err(PeekabooError::UnknownError("Failed to activate window".to_string()));
            }
            
            // Show window if minimized
            ShowWindow(hwnd, SW_RESTORE);
        }
        Ok(())
    }
}

#[cfg(target_os = "windows")]
impl ApplicationManager for WindowsPlatform {
    fn get_all_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>> {
        let mut applications = Vec::new();
        
        unsafe {
            let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
                .map_err(|e| PeekabooError::UnknownError(e.to_string()))?;
            
            let mut process_entry = PROCESSENTRY32W {
                dwSize: std::mem::size_of::<PROCESSENTRY32W>() as u32,
                ..Default::default()
            };
            
            if Process32FirstW(snapshot, &mut process_entry).as_bool() {
                loop {
                    let pid = process_entry.th32ProcessID as i32;
                    if let Ok(app_info) = get_application_info(pid, &process_entry) {
                        applications.push(app_info);
                    }
                    
                    if !Process32NextW(snapshot, &mut process_entry).as_bool() {
                        break;
                    }
                }
            }
            
            CloseHandle(snapshot);
        }
        
        Ok(applications)
    }
    
    fn find_application(&self, identifier: &str) -> PeekabooResult<ApplicationInfo> {
        let apps = self.get_all_applications()?;
        
        // Try to find by PID first
        if let Ok(pid) = identifier.parse::<i32>() {
            if let Some(app) = apps.iter().find(|a| a.pid == pid) {
                return Ok(app.clone());
            }
        }
        
        // Try to find by name or bundle ID
        apps.into_iter()
            .find(|app| {
                app.app_name.to_lowercase().contains(&identifier.to_lowercase()) ||
                app.bundle_id.to_lowercase().contains(&identifier.to_lowercase())
            })
            .ok_or_else(|| PeekabooError::AppNotFound(identifier.to_string()))
    }
    
    fn activate_application(&self, app: &ApplicationInfo) -> PeekabooResult<()> {
        // Try to activate the first window of the application
        let windows = self.get_windows_for_app(app.pid)?;
        if let Some(window) = windows.first() {
            self.activate_window(window)?;
        }
        Ok(())
    }
    
    fn is_application_active(&self, app: &ApplicationInfo) -> PeekabooResult<bool> {
        Ok(app.is_active)
    }
}

#[cfg(target_os = "windows")]
impl PermissionManager for WindowsPlatform {
    fn check_screen_recording_permission(&self) -> bool {
        // On Windows, screen recording is generally allowed
        // Check if we can access the desktop
        unsafe {
            let desktop_hwnd = GetDesktopWindow();
            let desktop_dc = GetDC(desktop_hwnd);
            let has_access = !desktop_dc.is_invalid();
            if has_access {
                ReleaseDC(desktop_hwnd, desktop_dc);
            }
            has_access
        }
    }
    
    fn check_accessibility_permission(&self) -> bool {
        // On Windows, basic window enumeration is generally allowed
        true
    }
    
    fn request_screen_recording_permission(&self) -> PeekabooResult<bool> {
        Ok(self.check_screen_recording_permission())
    }
    
    fn request_accessibility_permission(&self) -> PeekabooResult<bool> {
        Ok(self.check_accessibility_permission())
    }
}

#[cfg(target_os = "windows")]
impl Platform for WindowsPlatform {
    fn platform_name(&self) -> &'static str {
        "windows"
    }
    
    fn platform_version(&self) -> String {
        // Get Windows version
        unsafe {
            let major = GetSystemMetrics(SM_CXSCREEN); // Placeholder - would use proper version API
            format!("Windows {}", major)
        }
    }
    
    fn initialize(&mut self) -> PeekabooResult<()> {
        if !self.check_screen_recording_permission() {
            return Err(PeekabooError::ScreenRecordingPermissionDenied);
        }
        self.initialized = true;
        Ok(())
    }
    
    fn cleanup(&mut self) -> PeekabooResult<()> {
        self.initialized = false;
        Ok(())
    }
}

// Non-Windows stub implementations
#[cfg(not(target_os = "windows"))]
impl ScreenCapture for WindowsPlatform {
    fn capture_display(&self, _display_index: usize, _output_path: &str, _format: ImageFormat) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn capture_all_displays(&self, _base_path: Option<&str>, _format: ImageFormat) -> PeekabooResult<Vec<String>> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn capture_window(&self, _window: &WindowData, _output_path: &str, _format: ImageFormat) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn get_display_count(&self) -> PeekabooResult<usize> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
}

#[cfg(not(target_os = "windows"))]
impl WindowManager for WindowsPlatform {
    fn get_windows_for_app(&self, _pid: i32) -> PeekabooResult<Vec<WindowData>> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn find_window_by_title(&self, _pid: i32, _title_substring: &str) -> PeekabooResult<WindowData> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn get_window_by_index(&self, _pid: i32, _index: i32) -> PeekabooResult<WindowData> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn activate_window(&self, _window: &WindowData) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
}

#[cfg(not(target_os = "windows"))]
impl ApplicationManager for WindowsPlatform {
    fn get_all_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn find_application(&self, _identifier: &str) -> PeekabooResult<ApplicationInfo> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn activate_application(&self, _app: &ApplicationInfo) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    
    fn is_application_active(&self, _app: &ApplicationInfo) -> PeekabooResult<bool> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
}

#[cfg(not(target_os = "windows"))]
impl PermissionManager for WindowsPlatform {
    fn check_screen_recording_permission(&self) -> bool { false }
    fn check_accessibility_permission(&self) -> bool { false }
    fn request_screen_recording_permission(&self) -> PeekabooResult<bool> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    fn request_accessibility_permission(&self) -> PeekabooResult<bool> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
}

#[cfg(not(target_os = "windows"))]
impl Platform for WindowsPlatform {
    fn platform_name(&self) -> &'static str { "windows" }
    fn platform_version(&self) -> String { "Not available".to_string() }
    fn initialize(&mut self) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Windows platform not available".to_string()))
    }
    fn cleanup(&mut self) -> PeekabooResult<()> { Ok(()) }
}

// Helper functions and structures

#[cfg(target_os = "windows")]
struct EnumWindowsContext<'a> {
    target_pid: u32,
    windows: &'a mut Vec<WindowData>,
    window_index: i32,
}

#[cfg(target_os = "windows")]
unsafe extern "system" fn enum_windows_proc(hwnd: HWND, lparam: LPARAM) -> BOOL {
    let context = &mut *(lparam.0 as *mut EnumWindowsContext);
    
    // Get window process ID
    let mut window_pid: u32 = 0;
    GetWindowThreadProcessId(hwnd, Some(&mut window_pid));
    
    if window_pid == context.target_pid {
        // Get window title
        let mut title_buffer = [0u16; 256];
        let title_len = GetWindowTextW(hwnd, &mut title_buffer);
        let title = OsString::from_wide(&title_buffer[..title_len as usize])
            .to_string_lossy()
            .to_string();
        
        // Get window bounds
        let mut rect = RECT::default();
        GetWindowRect(hwnd, &mut rect);
        
        let window_data = WindowData {
            window_id: hwnd.0 as u32,
            title,
            bounds: WindowBounds {
                x_coordinate: rect.left,
                y_coordinate: rect.top,
                width: rect.right - rect.left,
                height: rect.bottom - rect.top,
            },
            is_on_screen: IsWindowVisible(hwnd).as_bool(),
            window_index: context.window_index,
        };
        
        context.windows.push(window_data);
        context.window_index += 1;
    }
    
    TRUE
}

#[cfg(target_os = "windows")]
fn get_application_info(pid: i32, process_entry: &PROCESSENTRY32W) -> PeekabooResult<ApplicationInfo> {
    let app_name = OsString::from_wide(&process_entry.szExeFile)
        .to_string_lossy()
        .trim_end_matches('\0')
        .to_string();
    
    // Use executable name as bundle_id for Windows
    let bundle_id = app_name.clone();
    
    Ok(ApplicationInfo {
        app_name,
        bundle_id,
        pid,
        is_active: false, // Simplified - would need more complex logic
        window_count: 1,  // Simplified - would need to count actual windows
    })
}

#[cfg(target_os = "windows")]
fn save_bitmap_to_file(bitmap: HBITMAP, output_path: &str, format: ImageFormat) -> PeekabooResult<()> {
    // This is a simplified implementation
    // In a full implementation, we'd use proper image encoding libraries
    // For now, we'll return success and let the caller handle the actual file writing
    
    // TODO: Implement proper bitmap to file conversion
    // This would involve:
    // 1. Getting bitmap data
    // 2. Converting to PNG/JPEG format
    // 3. Writing to file
    
    Err(PeekabooError::UnknownError("Bitmap saving not yet implemented".to_string()))
}

fn generate_output_path(base_path: Option<&str>, display_index: usize, format: &ImageFormat) -> String {
    let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S");
    let filename = format!("screenshot_display_{}_{}.{}", display_index, timestamp, format.extension());
    
    if let Some(base) = base_path {
        format!("{}\\{}", base, filename)
    } else {
        filename
    }
}
