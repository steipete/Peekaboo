use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{ApplicationInfo, WindowBounds, WindowData, WindowInfo};
use crate::traits::{ApplicationFinder, PermissionChecker, ScreenCapture, ScreenInfo, WindowManager};
use std::collections::HashMap;
use std::ffi::OsString;
use std::os::windows::ffi::OsStringExt;
use std::ptr;

// Windows API imports
use winapi::shared::windef::{HWND, RECT};
use winapi::shared::minwindef::{BOOL, DWORD, FALSE, TRUE, LPARAM};
use winapi::um::winuser::{
    EnumWindows, GetWindowTextW, GetWindowThreadProcessId, IsWindowVisible,
    GetWindowRect, SetForegroundWindow, ShowWindow, SW_RESTORE,
    GetDesktopWindow, GetDC, ReleaseDC, GetDeviceCaps, HORZRES, VERTRES
};
use winapi::um::processthreadsapi::OpenProcess;
use winapi::um::psapi::{EnumProcesses, GetProcessImageFileNameW};
use winapi::um::handleapi::CloseHandle;
use winapi::um::winnt::{PROCESS_QUERY_INFORMATION, PROCESS_VM_READ};
use winapi::um::wingdi::{CreateCompatibleDC, CreateCompatibleBitmap, SelectObject, BitBlt, SRCCOPY};

/// Windows-specific window manager
pub struct WindowsWindowManager;

impl WindowsWindowManager {
    pub fn new() -> PeekabooResult<Self> {
        Ok(Self)
    }
    
    fn get_window_text(hwnd: HWND) -> String {
        unsafe {
            let mut buffer = [0u16; 512];
            let len = GetWindowTextW(hwnd, buffer.as_mut_ptr(), buffer.len() as i32);
            if len > 0 {
                OsString::from_wide(&buffer[..len as usize])
                    .to_string_lossy()
                    .to_string()
            } else {
                "Untitled".to_string()
            }
        }
    }
    
    fn get_window_process_id(hwnd: HWND) -> DWORD {
        unsafe {
            let mut process_id = 0;
            GetWindowThreadProcessId(hwnd, &mut process_id);
            process_id
        }
    }
    
    fn get_window_rect_bounds(hwnd: HWND) -> PeekabooResult<WindowBounds> {
        unsafe {
            let mut rect = RECT {
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
            };
            
            if GetWindowRect(hwnd, &mut rect) != 0 {
                Ok(WindowBounds::new(
                    rect.left,
                    rect.top,
                    rect.right - rect.left,
                    rect.bottom - rect.top,
                ))
            } else {
                Err(PeekabooError::system_error("Failed to get window rect".to_string()))
            }
        }
    }
}

impl WindowManager for WindowsWindowManager {
    fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>> {
        let mut windows = Vec::new();
        let target_pid = pid as DWORD;
        
        unsafe extern "system" fn enum_windows_proc(hwnd: HWND, lparam: LPARAM) -> BOOL {
            let windows_ptr = lparam as *mut Vec<WindowData>;
            let windows = &mut *windows_ptr;
            let target_pid = *(windows.as_ptr() as *const DWORD);
            
            let window_pid = WindowsWindowManager::get_window_process_id(hwnd);
            
            if window_pid == target_pid && IsWindowVisible(hwnd) != 0 {
                let title = WindowsWindowManager::get_window_text(hwnd);
                let bounds = WindowsWindowManager::get_window_rect_bounds(hwnd)
                    .unwrap_or_else(|_| WindowBounds::new(0, 0, 800, 600));
                
                let window_data = WindowData {
                    window_id: hwnd as u32,
                    title,
                    bounds,
                    is_on_screen: true,
                    window_index: windows.len() as i32,
                };
                
                windows.push(window_data);
            }
            
            TRUE
        }
        
        unsafe {
            // Store target PID at the beginning of the vector's memory
            let mut context = vec![target_pid as WindowData; 1];
            context.clear();
            
            EnumWindows(
                Some(enum_windows_proc),
                &mut context as *mut Vec<WindowData> as LPARAM,
            );
            
            windows = context;
        }
        
        Ok(windows)
    }
    
    fn get_windows_info_for_app(
        &self,
        pid: i32,
        include_off_screen: bool,
        include_bounds: bool,
        include_ids: bool,
    ) -> PeekabooResult<Vec<WindowInfo>> {
        let windows = self.get_windows_for_app(pid)?;
        let mut window_infos = Vec::new();
        
        for (index, window) in windows.iter().enumerate() {
            if !include_off_screen && !window.is_on_screen {
                continue;
            }
            
            let window_info = WindowInfo {
                window_title: window.title.clone(),
                window_id: if include_ids { Some(window.window_id) } else { None },
                window_index: Some(index as i32),
                bounds: if include_bounds { Some(window.bounds.clone()) } else { None },
                is_on_screen: Some(window.is_on_screen),
            };
            
            window_infos.push(window_info);
        }
        
        Ok(window_infos)
    }
    
    fn activate_window(&self, window_id: u32) -> PeekabooResult<()> {
        unsafe {
            let hwnd = window_id as HWND;
            
            // Restore window if minimized
            ShowWindow(hwnd, SW_RESTORE);
            
            // Bring to foreground
            if SetForegroundWindow(hwnd) != 0 {
                Ok(())
            } else {
                Err(PeekabooError::system_error("Failed to activate window".to_string()))
            }
        }
    }
    
    fn get_window_by_title(&self, pid: i32, title: &str) -> PeekabooResult<WindowData> {
        let windows = self.get_windows_for_app(pid)?;
        
        for window in windows {
            if window.title.to_lowercase().contains(&title.to_lowercase()) {
                return Ok(window);
            }
        }
        
        Err(PeekabooError::WindowNotFound)
    }
    
    fn get_window_by_index(&self, pid: i32, index: i32) -> PeekabooResult<WindowData> {
        let windows = self.get_windows_for_app(pid)?;
        
        if index >= 0 && (index as usize) < windows.len() {
            Ok(windows[index as usize].clone())
        } else {
            Err(PeekabooError::invalid_window_index(index))
        }
    }
}

/// Windows-specific application finder
pub struct WindowsApplicationFinder;

impl WindowsApplicationFinder {
    pub fn new() -> PeekabooResult<Self> {
        Ok(Self)
    }
    
    fn get_process_name(&self, pid: DWORD) -> String {
        unsafe {
            let process_handle = OpenProcess(
                PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
                FALSE,
                pid,
            );
            
            if process_handle.is_null() {
                return format!("Process {}", pid);
            }
            
            let mut buffer = [0u16; 512];
            let len = GetProcessImageFileNameW(
                process_handle,
                buffer.as_mut_ptr(),
                buffer.len() as DWORD,
            );
            
            CloseHandle(process_handle);
            
            if len > 0 {
                let path = OsString::from_wide(&buffer[..len as usize])
                    .to_string_lossy()
                    .to_string();
                    
                // Extract just the filename
                if let Some(filename) = path.split('\\').last() {
                    filename.trim_end_matches(".exe").to_string()
                } else {
                    format!("Process {}", pid)
                }
            } else {
                format!("Process {}", pid)
            }
        }
    }
}

impl ApplicationFinder for WindowsApplicationFinder {
    fn get_all_running_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>> {
        let mut applications = Vec::new();
        let mut seen_names = HashMap::new();
        
        unsafe {
            let mut processes = [0u32; 1024];
            let mut bytes_returned = 0;
            
            if EnumProcesses(
                processes.as_mut_ptr(),
                (processes.len() * std::mem::size_of::<DWORD>()) as DWORD,
                &mut bytes_returned,
            ) == 0 {
                return Err(PeekabooError::system_error("Failed to enumerate processes".to_string()));
            }
            
            let process_count = bytes_returned as usize / std::mem::size_of::<DWORD>();
            
            for &pid in &processes[..process_count] {
                if pid == 0 {
                    continue;
                }
                
                let app_name = self.get_process_name(pid);
                
                // Skip system processes
                if app_name.starts_with("System") || app_name.contains("svchost") {
                    continue;
                }
                
                let entry = seen_names.entry(app_name.clone()).or_insert_with(|| {
                    ApplicationInfo {
                        app_name: app_name.clone(),
                        bundle_id: format!("windows.{}", app_name),
                        pid: pid as i32,
                        is_active: false,
                        window_count: 0,
                    }
                });
                
                // Update window count
                if let Ok(count) = self.get_window_count(pid as i32) {
                    entry.window_count += count;
                }
            }
        }
        
        applications.extend(seen_names.into_values());
        applications.sort_by(|a, b| a.app_name.cmp(&b.app_name));
        
        Ok(applications)
    }
    
    fn find_application(&self, identifier: &str) -> PeekabooResult<ApplicationInfo> {
        // Try to parse as PID first
        if let Ok(pid) = identifier.parse::<i32>() {
            let app_name = self.get_process_name(pid as DWORD);
            let window_count = self.get_window_count(pid).unwrap_or(0);
            return Ok(ApplicationInfo {
                app_name,
                bundle_id: format!("windows.pid.{}", pid),
                pid,
                is_active: self.is_application_active(pid).unwrap_or(false),
                window_count,
            });
        }
        
        // Search by name
        let applications = self.get_all_running_applications()?;
        for app in applications {
            if app.app_name.to_lowercase().contains(&identifier.to_lowercase()) ||
               app.bundle_id.to_lowercase().contains(&identifier.to_lowercase()) {
                return Ok(app);
            }
        }
        
        Err(PeekabooError::AppNotFound(identifier.to_string()))
    }
    
    fn is_application_active(&self, _pid: i32) -> PeekabooResult<bool> {
        // On Windows, determining if an application is "active" requires checking foreground window
        // For now, return false and implement this later
        Ok(false)
    }
    
    fn get_window_count(&self, pid: i32) -> PeekabooResult<i32> {
        let window_manager = WindowsWindowManager::new()?;
        let windows = window_manager.get_windows_for_app(pid)?;
        Ok(windows.len() as i32)
    }
}

/// Windows-specific screen capture
pub struct WindowsScreenCapture;

impl WindowsScreenCapture {
    pub fn new() -> PeekabooResult<Self> {
        Ok(Self)
    }
}

impl ScreenCapture for WindowsScreenCapture {
    fn capture_screen(&self, _screen_index: Option<i32>, output_path: &str) -> PeekabooResult<String> {
        // For now, use a simple implementation
        // In a full implementation, we'd use Windows GDI or newer APIs
        unsafe {
            let desktop_hwnd = GetDesktopWindow();
            let desktop_dc = GetDC(desktop_hwnd);
            
            if desktop_dc.is_null() {
                return Err(PeekabooError::system_error("Failed to get desktop DC".to_string()));
            }
            
            let width = GetDeviceCaps(desktop_dc, HORZRES);
            let height = GetDeviceCaps(desktop_dc, VERTRES);
            
            let mem_dc = CreateCompatibleDC(desktop_dc);
            let bitmap = CreateCompatibleBitmap(desktop_dc, width, height);
            
            if mem_dc.is_null() || bitmap.is_null() {
                ReleaseDC(desktop_hwnd, desktop_dc);
                return Err(PeekabooError::system_error("Failed to create compatible DC/bitmap".to_string()));
            }
            
            SelectObject(mem_dc, bitmap as *mut _);
            BitBlt(mem_dc, 0, 0, width, height, desktop_dc, 0, 0, SRCCOPY);
            
            // Here we would save the bitmap to file
            // For now, just return success
            ReleaseDC(desktop_hwnd, desktop_dc);
            
            // TODO: Implement actual bitmap saving
            crate::logger::warn("Windows screen capture not fully implemented yet");
            Ok(output_path.to_string())
        }
    }
    
    fn capture_window(&self, window_data: &WindowData, output_path: &str) -> PeekabooResult<String> {
        // TODO: Implement window-specific capture
        crate::logger::warn("Windows window capture not fully implemented yet");
        Ok(output_path.to_string())
    }
    
    fn get_available_screens(&self) -> PeekabooResult<Vec<ScreenInfo>> {
        unsafe {
            let desktop_hwnd = GetDesktopWindow();
            let desktop_dc = GetDC(desktop_hwnd);
            
            if desktop_dc.is_null() {
                return Ok(vec![ScreenInfo {
                    index: 0,
                    width: 1920,
                    height: 1080,
                    is_primary: true,
                }]);
            }
            
            let width = GetDeviceCaps(desktop_dc, HORZRES);
            let height = GetDeviceCaps(desktop_dc, VERTRES);
            
            ReleaseDC(desktop_hwnd, desktop_dc);
            
            Ok(vec![ScreenInfo {
                index: 0,
                width,
                height,
                is_primary: true,
            }])
        }
    }
}

/// Windows-specific permission checker
pub struct WindowsPermissionChecker;

impl WindowsPermissionChecker {
    pub fn new() -> Self {
        Self
    }
}

impl PermissionChecker for WindowsPermissionChecker {
    fn check_screen_recording_permission(&self) -> PeekabooResult<bool> {
        // On Windows, screen recording permissions are generally less restrictive
        // We can try to access the desktop
        unsafe {
            let desktop_hwnd = GetDesktopWindow();
            let desktop_dc = GetDC(desktop_hwnd);
            let has_access = !desktop_dc.is_null();
            if has_access {
                ReleaseDC(desktop_hwnd, desktop_dc);
            }
            Ok(has_access)
        }
    }
    
    fn check_accessibility_permission(&self) -> PeekabooResult<bool> {
        // On Windows, we generally have access to window enumeration
        // Check if we can enumerate windows
        unsafe {
            let mut count = 0;
            extern "system" fn count_windows(_hwnd: HWND, lparam: LPARAM) -> BOOL {
                let counter = lparam as *mut i32;
                *counter += 1;
                TRUE
            }
            
            EnumWindows(Some(count_windows), &mut count as *mut i32 as LPARAM);
            Ok(count > 0)
        }
    }
    
    fn request_screen_recording_permission(&self) -> PeekabooResult<()> {
        crate::logger::info("Screen recording on Windows typically doesn't require special permissions");
        Ok(())
    }
    
    fn request_accessibility_permission(&self) -> PeekabooResult<()> {
        crate::logger::info("Window management on Windows typically doesn't require special permissions");
        Ok(())
    }
}

