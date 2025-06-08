use crate::errors::PeekabooResult;
use crate::models::{ApplicationInfo, WindowData, ImageFormat};

/// Trait for screen capture operations
pub trait ScreenCapture {
    /// Capture a specific display by index
    fn capture_display(&self, display_index: usize, output_path: &str, format: ImageFormat) -> PeekabooResult<()>;
    
    /// Capture all displays
    fn capture_all_displays(&self, base_path: Option<&str>, format: ImageFormat) -> PeekabooResult<Vec<String>>;
    
    /// Capture a specific window
    fn capture_window(&self, window: &WindowData, output_path: &str, format: ImageFormat) -> PeekabooResult<()>;
    
    /// Get the number of available displays
    fn get_display_count(&self) -> PeekabooResult<usize>;
}

/// Trait for window management operations
pub trait WindowManager {
    /// Get all windows for a specific application by PID
    fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>>;
    
    /// Find a window by title substring
    fn find_window_by_title(&self, pid: i32, title_substring: &str) -> PeekabooResult<WindowData>;
    
    /// Get window by index (0 = frontmost)
    fn get_window_by_index(&self, pid: i32, index: i32) -> PeekabooResult<WindowData>;
    
    /// Activate/focus a window
    fn activate_window(&self, window: &WindowData) -> PeekabooResult<()>;
}

/// Trait for application discovery and management
pub trait ApplicationManager {
    /// Get all running applications
    fn get_all_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>>;
    
    /// Find an application by identifier (name, bundle ID, or PID)
    fn find_application(&self, identifier: &str) -> PeekabooResult<ApplicationInfo>;
    
    /// Activate/focus an application
    fn activate_application(&self, app: &ApplicationInfo) -> PeekabooResult<()>;
    
    /// Check if an application is currently active/focused
    fn is_application_active(&self, app: &ApplicationInfo) -> PeekabooResult<bool>;
}

/// Trait for system permission checking
pub trait PermissionManager {
    /// Check if screen recording permission is granted
    fn check_screen_recording_permission(&self) -> bool;
    
    /// Check if accessibility permission is granted
    fn check_accessibility_permission(&self) -> bool;
    
    /// Request screen recording permission (may show system dialog)
    fn request_screen_recording_permission(&self) -> PeekabooResult<bool>;
    
    /// Request accessibility permission (may show system dialog)
    fn request_accessibility_permission(&self) -> PeekabooResult<bool>;
}

/// Combined platform interface
pub trait Platform: ScreenCapture + WindowManager + ApplicationManager + PermissionManager {
    /// Get the platform name (e.g., "linux", "windows", "darwin")
    fn platform_name(&self) -> &'static str;
    
    /// Get the platform version
    fn platform_version(&self) -> String;
    
    /// Initialize the platform (setup any required resources)
    fn initialize(&mut self) -> PeekabooResult<()>;
    
    /// Cleanup platform resources
    fn cleanup(&mut self) -> PeekabooResult<()>;
}
