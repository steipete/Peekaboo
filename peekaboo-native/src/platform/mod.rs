use crate::traits::{ApplicationFinder, PermissionChecker, ScreenCapture, WindowManager};
use crate::errors::PeekabooResult;

#[cfg(target_os = "linux")]
pub mod linux;

#[cfg(target_os = "windows")]
pub mod windows;

/// Platform-specific implementations container
pub struct PlatformManager {
    pub window_manager: Box<dyn WindowManager>,
    pub application_finder: Box<dyn ApplicationFinder>,
    pub screen_capture: Box<dyn ScreenCapture>,
    pub permission_checker: Box<dyn PermissionChecker>,
}

impl PlatformManager {
    /// Create a new platform manager with appropriate implementations for the current platform
    pub fn new() -> PeekabooResult<Self> {
        #[cfg(target_os = "linux")]
        {
            Ok(Self {
                window_manager: Box::new(linux::LinuxWindowManager::new()?),
                application_finder: Box::new(linux::LinuxApplicationFinder::new()?),
                screen_capture: Box::new(linux::LinuxScreenCapture::new()?),
                permission_checker: Box::new(linux::LinuxPermissionChecker::new()),
            })
        }
        
        #[cfg(target_os = "windows")]
        {
            Ok(Self {
                window_manager: Box::new(windows::WindowsWindowManager::new()?),
                application_finder: Box::new(windows::WindowsApplicationFinder::new()?),
                screen_capture: Box::new(windows::WindowsScreenCapture::new()?),
                permission_checker: Box::new(windows::WindowsPermissionChecker::new()),
            })
        }
        
        #[cfg(not(any(target_os = "linux", target_os = "windows")))]
        {
            Err(crate::errors::PeekabooError::unsupported_platform(
                std::env::consts::OS.to_string()
            ))
        }
    }
}

/// Get the current platform name
pub fn get_platform_name() -> &'static str {
    std::env::consts::OS
}

/// Check if the current platform is supported
pub fn is_platform_supported() -> bool {
    matches!(std::env::consts::OS, "linux" | "windows")
}

