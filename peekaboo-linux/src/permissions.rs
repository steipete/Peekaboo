use crate::errors::{PeekabooError, PeekabooResult};
use std::env;
use std::process::Command;

pub struct PermissionsChecker;

impl PermissionsChecker {
    pub fn check_screen_recording_permission() -> bool {
        // On Linux, screen recording permissions are typically handled by:
        // 1. User being in the correct groups (e.g., video)
        // 2. Having access to the display server (X11/Wayland)
        // 3. Desktop environment permissions (for Wayland)

        // Check if we can access the display
        if let Ok(_) = env::var("DISPLAY") {
            // X11 environment
            Self::check_x11_access()
        } else if let Ok(_) = env::var("WAYLAND_DISPLAY") {
            // Wayland environment
            Self::check_wayland_access()
        } else {
            // No display server detected - this is common in headless environments
            // For operations that don't actually need screen capture (like listing apps),
            // we should be more lenient
            crate::logger::debug("No display server detected (DISPLAY or WAYLAND_DISPLAY not set) - headless environment");
            false
        }
    }

    pub fn check_accessibility_permission() -> bool {
        // On Linux, accessibility permissions are less restrictive than macOS
        // Most window management operations don't require special permissions
        // unless running in a sandboxed environment
        
        // Check if we can access basic window management
        Self::check_window_management_access()
    }

    pub fn require_screen_recording_permission() -> PeekabooResult<()> {
        if !Self::check_screen_recording_permission() {
            return Err(PeekabooError::ScreenRecordingPermissionDenied);
        }
        Ok(())
    }

    pub fn require_basic_permissions() -> PeekabooResult<()> {
        if !Self::check_basic_permissions() {
            return Err(PeekabooError::ScreenRecordingPermissionDenied);
        }
        Ok(())
    }

    pub fn require_accessibility_permission() -> PeekabooResult<()> {
        if !Self::check_accessibility_permission() {
            return Err(PeekabooError::AccessibilityPermissionDenied);
        }
        Ok(())
    }

    pub fn check_basic_permissions() -> bool {
        // Check if we can perform basic operations like listing processes
        // This is more lenient than screen recording permission
        
        // Check if we have access to /proc (needed for process information)
        match std::fs::read_dir("/proc") {
            Ok(_) => true,
            Err(e) => {
                crate::logger::warn(&format!("Cannot access /proc: {}", e));
                false
            }
        }
    }

    fn check_x11_access() -> bool {
        // Try to connect to X11 display
        match env::var("DISPLAY") {
            Ok(display) => {
                crate::logger::debug(&format!("Checking X11 access for display: {}", display));
                
                // Try to run a simple X11 command to test access
                match Command::new("xdpyinfo").output() {
                    Ok(output) => {
                        let success = output.status.success();
                        if !success {
                            crate::logger::warn("xdpyinfo failed - X11 access may be restricted");
                        }
                        success
                    }
                    Err(_) => {
                        // xdpyinfo not available, try alternative check
                        crate::logger::debug("xdpyinfo not available, trying alternative X11 check");
                        Self::check_x11_alternative()
                    }
                }
            }
            Err(_) => {
                crate::logger::warn("DISPLAY environment variable not set");
                false
            }
        }
    }

    fn check_x11_alternative() -> bool {
        // Alternative X11 check using xlsclients or xwininfo
        if let Ok(output) = Command::new("xlsclients").output() {
            return output.status.success();
        }
        
        if let Ok(output) = Command::new("xwininfo").arg("-root").arg("-tree").output() {
            return output.status.success();
        }

        // If no X11 tools are available, assume we have access
        // The actual screen capture will fail if we don't
        crate::logger::debug("No X11 tools available for permission check, assuming access");
        true
    }

    fn check_wayland_access() -> bool {
        match env::var("WAYLAND_DISPLAY") {
            Ok(display) => {
                crate::logger::debug(&format!("Checking Wayland access for display: {}", display));
                
                // Check if we can access the Wayland socket
                let socket_path = if let Ok(runtime_dir) = env::var("XDG_RUNTIME_DIR") {
                    format!("{}/{}", runtime_dir, display)
                } else {
                    format!("/run/user/{}/{}", Self::get_user_id(), display)
                };

                match std::fs::metadata(&socket_path) {
                    Ok(_) => {
                        crate::logger::debug(&format!("Wayland socket accessible at: {}", socket_path));
                        true
                    }
                    Err(e) => {
                        crate::logger::warn(&format!("Cannot access Wayland socket {}: {}", socket_path, e));
                        false
                    }
                }
            }
            Err(_) => {
                crate::logger::warn("WAYLAND_DISPLAY environment variable not set");
                false
            }
        }
    }

    fn check_window_management_access() -> bool {
        // Check if we can perform basic window management operations
        // This is typically allowed on Linux unless in a very restricted environment
        
        // Check if we're running in a known restricted environment
        if Self::is_sandboxed_environment() {
            crate::logger::warn("Running in sandboxed environment - window management may be restricted");
            return false;
        }

        // Check if we have access to /proc (needed for process information)
        match std::fs::read_dir("/proc") {
            Ok(_) => true,
            Err(e) => {
                crate::logger::warn(&format!("Cannot access /proc: {}", e));
                false
            }
        }
    }

    fn is_sandboxed_environment() -> bool {
        // Check for common sandboxing indicators
        
        // Flatpak
        if env::var("FLATPAK_ID").is_ok() {
            crate::logger::debug("Detected Flatpak environment");
            return true;
        }

        // Snap
        if env::var("SNAP").is_ok() {
            crate::logger::debug("Detected Snap environment");
            return true;
        }

        // AppImage
        if env::var("APPIMAGE").is_ok() {
            crate::logger::debug("Detected AppImage environment");
            return true;
        }

        // Docker/Container
        if std::path::Path::new("/.dockerenv").exists() {
            crate::logger::debug("Detected Docker environment");
            return true;
        }

        false
    }

    fn get_user_id() -> u32 {
        // Get the current user ID
        unsafe { libc::getuid() }
    }

    pub fn get_permission_status() -> (bool, bool) {
        let screen_recording = Self::check_screen_recording_permission();
        let accessibility = Self::check_accessibility_permission();
        
        crate::logger::debug(&format!(
            "Permission status - Screen recording: {}, Accessibility: {}",
            screen_recording, accessibility
        ));
        
        (screen_recording, accessibility)
    }

    pub fn get_environment_info() -> String {
        let mut info = Vec::new();

        // Display server
        if let Ok(display) = env::var("DISPLAY") {
            info.push(format!("X11 Display: {}", display));
        }
        if let Ok(wayland) = env::var("WAYLAND_DISPLAY") {
            info.push(format!("Wayland Display: {}", wayland));
        }

        // Desktop environment
        if let Ok(desktop) = env::var("XDG_CURRENT_DESKTOP") {
            info.push(format!("Desktop: {}", desktop));
        }
        if let Ok(session) = env::var("XDG_SESSION_TYPE") {
            info.push(format!("Session Type: {}", session));
        }

        // Sandboxing
        if Self::is_sandboxed_environment() {
            info.push("Sandboxed: Yes".to_string());
        }

        if info.is_empty() {
            "Unknown environment".to_string()
        } else {
            info.join(", ")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_permission_checker_creation() {
        // Just test that we can call the static methods without panicking
        let (screen, accessibility) = PermissionsChecker::get_permission_status();
        
        // In a test environment, these might be false, which is expected
        println!("Screen recording permission: {}", screen);
        println!("Accessibility permission: {}", accessibility);
    }

    #[test]
    fn test_environment_info() {
        let info = PermissionsChecker::get_environment_info();
        println!("Environment info: {}", info);
        
        // Should return some information, even if minimal
        assert!(!info.is_empty());
    }

    #[test]
    fn test_sandboxed_detection() {
        let is_sandboxed = PermissionsChecker::is_sandboxed_environment();
        println!("Is sandboxed: {}", is_sandboxed);
        
        // This test just verifies the function doesn't panic
        // The actual result depends on the test environment
    }

    #[test]
    fn test_user_id() {
        let uid = PermissionsChecker::get_user_id();
        println!("User ID: {}", uid);
        
        // Should return a valid user ID
        assert!(uid >= 0);
    }
}
