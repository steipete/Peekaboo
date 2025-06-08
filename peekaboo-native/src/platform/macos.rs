use crate::traits::{Platform, ScreenCapture, WindowManager, ApplicationManager, PermissionManager};
use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{ApplicationInfo, WindowData, ImageFormat};

pub struct MacOSPlatform;

impl MacOSPlatform {
    pub fn new() -> PeekabooResult<Self> {
        Ok(Self)
    }
}

// Stub implementations for macOS - the Swift binary should be used instead
impl ScreenCapture for MacOSPlatform {
    fn capture_display(&self, _display_index: usize, _output_path: &str, _format: ImageFormat) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn capture_all_displays(&self, _base_path: Option<&str>, _format: ImageFormat) -> PeekabooResult<Vec<String>> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn capture_window(&self, _window: &WindowData, _output_path: &str, _format: ImageFormat) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn get_display_count(&self) -> PeekabooResult<usize> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
}

impl WindowManager for MacOSPlatform {
    fn get_windows_for_app(&self, _pid: i32) -> PeekabooResult<Vec<WindowData>> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn find_window_by_title(&self, _pid: i32, _title_substring: &str) -> PeekabooResult<WindowData> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn get_window_by_index(&self, _pid: i32, _index: i32) -> PeekabooResult<WindowData> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn activate_window(&self, _window: &WindowData) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
}

impl ApplicationManager for MacOSPlatform {
    fn get_all_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn find_application(&self, _identifier: &str) -> PeekabooResult<ApplicationInfo> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn activate_application(&self, _app: &ApplicationInfo) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn is_application_active(&self, _app: &ApplicationInfo) -> PeekabooResult<bool> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
}

impl PermissionManager for MacOSPlatform {
    fn check_screen_recording_permission(&self) -> bool {
        false
    }
    
    fn check_accessibility_permission(&self) -> bool {
        false
    }
    
    fn request_screen_recording_permission(&self) -> PeekabooResult<bool> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn request_accessibility_permission(&self) -> PeekabooResult<bool> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
}

impl Platform for MacOSPlatform {
    fn platform_name(&self) -> &'static str {
        "darwin"
    }
    
    fn platform_version(&self) -> String {
        "Use Swift binary".to_string()
    }
    
    fn initialize(&mut self) -> PeekabooResult<()> {
        Err(PeekabooError::UnknownError("Use the Swift binary for macOS".to_string()))
    }
    
    fn cleanup(&mut self) -> PeekabooResult<()> {
        Ok(())
    }
}

