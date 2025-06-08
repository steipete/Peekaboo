use crate::traits::{Platform, ScreenCapture, WindowManager, ApplicationManager, PermissionManager};
use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{ApplicationInfo, WindowData, ImageFormat, WindowBounds};
use crate::utils::file_utils;
use std::process::Command;
use std::fs;
use std::path::Path;

pub struct LinuxPlatform {
    display_server: DisplayServer,
}

#[derive(Debug, Clone)]
enum DisplayServer {
    X11,
    Wayland,
}

impl LinuxPlatform {
    pub fn new() -> PeekabooResult<Self> {
        let display_server = detect_display_server()?;
        Ok(Self { display_server })
    }
    
    fn get_screenshot_command(&self, output_path: &str) -> Vec<String> {
        match self.display_server {
            DisplayServer::X11 => {
                // Try scrot first, then ImageMagick import
                if command_exists("scrot") {
                    vec!["scrot".to_string(), output_path.to_string()]
                } else if command_exists("import") {
                    vec!["import".to_string(), "-window".to_string(), "root".to_string(), output_path.to_string()]
                } else {
                    vec!["xwd".to_string(), "-root".to_string(), "-out".to_string(), output_path.to_string()]
                }
            }
            DisplayServer::Wayland => {
                // Try grim first, then wl-copy with ImageMagick
                if command_exists("grim") {
                    vec!["grim".to_string(), output_path.to_string()]
                } else {
                    vec!["gnome-screenshot".to_string(), "-f".to_string(), output_path.to_string()]
                }
            }
        }
    }
    
    fn get_window_screenshot_command(&self, window_id: u32, output_path: &str) -> Vec<String> {
        match self.display_server {
            DisplayServer::X11 => {
                if command_exists("scrot") {
                    vec!["scrot".to_string(), "-s".to_string(), output_path.to_string()]
                } else if command_exists("import") {
                    vec!["import".to_string(), "-window".to_string(), window_id.to_string(), output_path.to_string()]
                } else {
                    vec!["xwd".to_string(), "-id".to_string(), window_id.to_string(), "-out".to_string(), output_path.to_string()]
                }
            }
            DisplayServer::Wayland => {
                // Wayland window capture is more complex, use grim with slurp
                if command_exists("grim") && command_exists("slurp") {
                    vec!["sh".to_string(), "-c".to_string(), 
                         format!("grim -g \"$(slurp)\" {}", output_path)]
                } else {
                    vec!["gnome-screenshot".to_string(), "-w".to_string(), "-f".to_string(), output_path.to_string()]
                }
            }
        }
    }
}

impl ScreenCapture for LinuxPlatform {
    fn capture_display(&self, display_index: usize, output_path: &str, format: ImageFormat) -> PeekabooResult<()> {
        // For now, capture the main display (display_index is ignored on Linux)
        let cmd_args = self.get_screenshot_command(output_path);
        
        let output = Command::new(&cmd_args[0])
            .args(&cmd_args[1..])
            .output()
            .map_err(|e| PeekabooError::CaptureCreationFailed(e.to_string()))?;
        
        if !output.status.success() {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            return Err(PeekabooError::CaptureCreationFailed(error_msg.to_string()));
        }
        
        // Convert format if needed
        if let Some(converted_path) = convert_image_format(output_path, format)? {
            if converted_path != output_path {
                fs::rename(converted_path, output_path)?;
            }
        }
        
        Ok(())
    }
    
    fn capture_all_displays(&self, base_path: Option<&str>, format: ImageFormat) -> PeekabooResult<Vec<String>> {
        // For Linux, we'll capture the main display
        let output_path = generate_output_path(base_path, 0, &format);
        self.capture_display(0, &output_path, format)?;
        Ok(vec![output_path])
    }
    
    fn capture_window(&self, window: &WindowData, output_path: &str, format: ImageFormat) -> PeekabooResult<()> {
        let cmd_args = self.get_window_screenshot_command(window.window_id, output_path);
        
        let output = Command::new(&cmd_args[0])
            .args(&cmd_args[1..])
            .output()
            .map_err(|e| PeekabooError::WindowCaptureFailed(e.to_string()))?;
        
        if !output.status.success() {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            return Err(PeekabooError::WindowCaptureFailed(error_msg.to_string()));
        }
        
        // Convert format if needed
        if let Some(converted_path) = convert_image_format(output_path, format)? {
            if converted_path != output_path {
                fs::rename(converted_path, output_path)?;
            }
        }
        
        Ok(())
    }
    
    fn get_display_count(&self) -> PeekabooResult<usize> {
        // For simplicity, return 1 display on Linux
        // In a full implementation, we'd query X11/Wayland for actual display count
        Ok(1)
    }
}

impl WindowManager for LinuxPlatform {
    fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>> {
        match self.display_server {
            DisplayServer::X11 => get_x11_windows_for_pid(pid),
            DisplayServer::Wayland => get_wayland_windows_for_pid(pid),
        }
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
        match self.display_server {
            DisplayServer::X11 => {
                let output = Command::new("xdotool")
                    .args(&["windowactivate", &window.window_id.to_string()])
                    .output()
                    .map_err(|e| PeekabooError::UnknownError(e.to_string()))?;
                
                if !output.status.success() {
                    return Err(PeekabooError::UnknownError("Failed to activate window".to_string()));
                }
            }
            DisplayServer::Wayland => {
                // Wayland doesn't allow arbitrary window activation for security reasons
                // This would require compositor-specific protocols
                return Err(PeekabooError::UnknownError("Window activation not supported on Wayland".to_string()));
            }
        }
        Ok(())
    }
}

impl ApplicationManager for LinuxPlatform {
    fn get_all_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>> {
        get_running_applications()
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
        // For Linux, we'll consider an app active if it has focused windows
        // This is a simplified implementation
        Ok(app.is_active)
    }
}

impl PermissionManager for LinuxPlatform {
    fn check_screen_recording_permission(&self) -> bool {
        // On Linux, screen recording permissions are generally not restricted
        // Check if we have the necessary tools available
        match self.display_server {
            DisplayServer::X11 => command_exists("scrot") || command_exists("import") || command_exists("xwd"),
            DisplayServer::Wayland => command_exists("grim") || command_exists("gnome-screenshot"),
        }
    }
    
    fn check_accessibility_permission(&self) -> bool {
        // On Linux, accessibility permissions are generally not restricted
        // Check if we have the necessary tools available
        command_exists("xdotool") || command_exists("wmctrl")
    }
    
    fn request_screen_recording_permission(&self) -> PeekabooResult<bool> {
        // On Linux, no explicit permission request is needed
        Ok(self.check_screen_recording_permission())
    }
    
    fn request_accessibility_permission(&self) -> PeekabooResult<bool> {
        // On Linux, no explicit permission request is needed
        Ok(self.check_accessibility_permission())
    }
}

impl Platform for LinuxPlatform {
    fn platform_name(&self) -> &'static str {
        "linux"
    }
    
    fn platform_version(&self) -> String {
        // Get Linux distribution info
        if let Ok(content) = fs::read_to_string("/etc/os-release") {
            for line in content.lines() {
                if line.starts_with("PRETTY_NAME=") {
                    return line.split('=').nth(1)
                        .unwrap_or("Unknown Linux")
                        .trim_matches('"')
                        .to_string();
                }
            }
        }
        "Unknown Linux".to_string()
    }
    
    fn initialize(&mut self) -> PeekabooResult<()> {
        // Check if required tools are available
        if !self.check_screen_recording_permission() {
            return Err(PeekabooError::ScreenRecordingPermissionDenied);
        }
        Ok(())
    }
    
    fn cleanup(&mut self) -> PeekabooResult<()> {
        // No cleanup needed for Linux platform
        Ok(())
    }
}

// Helper functions

fn detect_display_server() -> PeekabooResult<DisplayServer> {
    if std::env::var("WAYLAND_DISPLAY").is_ok() {
        Ok(DisplayServer::Wayland)
    } else if std::env::var("DISPLAY").is_ok() {
        Ok(DisplayServer::X11)
    } else {
        Err(PeekabooError::NoDisplaysAvailable)
    }
}

fn command_exists(command: &str) -> bool {
    Command::new("which")
        .arg(command)
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

fn convert_image_format(path: &str, target_format: ImageFormat) -> PeekabooResult<Option<String>> {
    let path_obj = Path::new(path);
    let current_ext = path_obj.extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or("");
    
    let target_ext = target_format.extension();
    
    if current_ext == target_ext {
        return Ok(None);
    }
    
    // Use ImageMagick convert if available
    if command_exists("convert") {
        let new_path = path_obj.with_extension(target_ext);
        let new_path_str = new_path.to_string_lossy().to_string();
        
        let output = Command::new("convert")
            .args(&[path, &new_path_str])
            .output()
            .map_err(|e| PeekabooError::FileWriteError {
                path: new_path_str.clone(),
                details: e.to_string(),
            })?;
        
        if !output.status.success() {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            return Err(PeekabooError::FileWriteError {
                path: new_path_str,
                details: error_msg.to_string(),
            });
        }
        
        // Remove original file
        fs::remove_file(path)?;
        
        Ok(Some(new_path_str))
    } else {
        Ok(None)
    }
}

fn generate_output_path(base_path: Option<&str>, display_index: usize, format: &ImageFormat) -> String {
    let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S");
    let filename = format!("screenshot_display_{}_{}.{}", display_index, timestamp, format.extension());
    
    if let Some(base) = base_path {
        file_utils::join_path(base, &filename)
    } else {
        filename
    }
}

fn get_x11_windows_for_pid(pid: i32) -> PeekabooResult<Vec<WindowData>> {
    // Use wmctrl to get window list
    let output = Command::new("wmctrl")
        .args(&["-l", "-p"])
        .output()
        .map_err(|e| PeekabooError::UnknownError(e.to_string()))?;
    
    if !output.status.success() {
        return Err(PeekabooError::UnknownError("Failed to get window list".to_string()));
    }
    
    let output_str = String::from_utf8_lossy(&output.stdout);
    let mut windows = Vec::new();
    let mut window_index = 0;
    
    for line in output_str.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 4 {
            if let (Ok(window_id), Ok(window_pid)) = (
                u32::from_str_radix(parts[0].trim_start_matches("0x"), 16),
                parts[2].parse::<i32>()
            ) {
                if window_pid == pid {
                    let title = parts[4..].join(" ");
                    windows.push(WindowData {
                        window_id,
                        title,
                        bounds: WindowBounds {
                            x_coordinate: 0,
                            y_coordinate: 0,
                            width: 800,
                            height: 600,
                        },
                        is_on_screen: true,
                        window_index,
                    });
                    window_index += 1;
                }
            }
        }
    }
    
    Ok(windows)
}

fn get_wayland_windows_for_pid(_pid: i32) -> PeekabooResult<Vec<WindowData>> {
    // Wayland doesn't provide a standard way to enumerate windows
    // This would require compositor-specific protocols
    Err(PeekabooError::UnknownError("Window enumeration not supported on Wayland".to_string()))
}

fn get_running_applications() -> PeekabooResult<Vec<ApplicationInfo>> {
    let mut applications = Vec::new();
    
    // Read from /proc to get running processes
    let proc_dir = fs::read_dir("/proc")
        .map_err(|e| PeekabooError::UnknownError(e.to_string()))?;
    
    for entry in proc_dir {
        if let Ok(entry) = entry {
            if let Ok(pid) = entry.file_name().to_string_lossy().parse::<i32>() {
                if let Ok(app_info) = get_application_info(pid) {
                    applications.push(app_info);
                }
            }
        }
    }
    
    Ok(applications)
}

fn get_application_info(pid: i32) -> PeekabooResult<ApplicationInfo> {
    let comm_path = format!("/proc/{}/comm", pid);
    let cmdline_path = format!("/proc/{}/cmdline", pid);
    
    let app_name = fs::read_to_string(&comm_path)
        .map_err(|e| PeekabooError::UnknownError(e.to_string()))?
        .trim()
        .to_string();
    
    let cmdline = fs::read_to_string(&cmdline_path)
        .unwrap_or_default()
        .replace('\0', " ");
    
    // Use command line as bundle_id for Linux
    let bundle_id = if cmdline.is_empty() { app_name.clone() } else { cmdline };
    
    Ok(ApplicationInfo {
        app_name,
        bundle_id,
        pid,
        is_active: false, // Simplified - would need more complex logic to determine
        window_count: 1,  // Simplified - would need to count actual windows
    })
}
