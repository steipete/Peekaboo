use crate::errors::PeekabooResult;
use crate::models::{ApplicationInfo, WindowData, WindowInfo};

/// Trait for platform-specific window management operations
pub trait WindowManager: Send + Sync {
    /// Get all windows for a specific application process
    fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>>;
    
    /// Get window information with optional details
    fn get_windows_info_for_app(
        &self,
        pid: i32,
        include_off_screen: bool,
        include_bounds: bool,
        include_ids: bool,
    ) -> PeekabooResult<Vec<WindowInfo>>;
    
    /// Activate/focus a specific window
    fn activate_window(&self, window_id: u32) -> PeekabooResult<()>;
    
    /// Find a window by title substring
    fn get_window_by_title(&self, pid: i32, title: &str) -> PeekabooResult<WindowData>;
    
    /// Get a window by its index (0-based)
    fn get_window_by_index(&self, pid: i32, index: i32) -> PeekabooResult<WindowData>;
}

/// Trait for platform-specific application discovery
pub trait ApplicationFinder: Send + Sync {
    /// Get all running applications
    fn get_all_running_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>>;
    
    /// Find an application by identifier (name, bundle ID, or PID)
    fn find_application(&self, identifier: &str) -> PeekabooResult<ApplicationInfo>;
    
    /// Check if an application is currently active/focused
    fn is_application_active(&self, pid: i32) -> PeekabooResult<bool>;
    
    /// Get the number of windows for an application
    fn get_window_count(&self, pid: i32) -> PeekabooResult<i32>;
}

/// Trait for platform-specific screen capture operations
pub trait ScreenCapture: Send + Sync {
    /// Capture the entire screen or a specific screen by index
    fn capture_screen(&self, screen_index: Option<i32>, output_path: &str) -> PeekabooResult<String>;
    
    /// Capture a specific window
    fn capture_window(&self, window_data: &WindowData, output_path: &str) -> PeekabooResult<String>;
    
    /// Get available screens/displays
    fn get_available_screens(&self) -> PeekabooResult<Vec<ScreenInfo>>;
}

/// Information about a screen/display
#[derive(Debug, Clone)]
pub struct ScreenInfo {
    pub index: i32,
    pub width: i32,
    pub height: i32,
    pub is_primary: bool,
}

/// Trait for platform-specific permission checking
pub trait PermissionChecker: Send + Sync {
    /// Check if screen recording permission is granted
    fn check_screen_recording_permission(&self) -> PeekabooResult<bool>;
    
    /// Check if accessibility permission is granted (for window management)
    fn check_accessibility_permission(&self) -> PeekabooResult<bool>;
    
    /// Request screen recording permission (if possible)
    fn request_screen_recording_permission(&self) -> PeekabooResult<()>;
    
    /// Request accessibility permission (if possible)
    fn request_accessibility_permission(&self) -> PeekabooResult<()>;
}

