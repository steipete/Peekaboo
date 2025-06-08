use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{ApplicationInfo, WindowBounds, WindowData, WindowInfo};
use crate::traits::{ApplicationFinder, PermissionChecker, ScreenCapture, ScreenInfo, WindowManager};
use std::collections::HashMap;
use std::process::Command;
use std::fs;
use std::path::Path;

/// Linux-specific window manager using X11/Wayland
pub struct LinuxWindowManager {
    display_server: DisplayServer,
}

#[derive(Debug, Clone)]
enum DisplayServer {
    X11,
    Wayland,
    Unknown,
}

impl LinuxWindowManager {
    pub fn new() -> PeekabooResult<Self> {
        let display_server = detect_display_server();
        Ok(Self { display_server })
    }
    
    fn get_windows_via_wmctrl(&self, pid: i32) -> PeekabooResult<Vec<WindowData>> {
        let output = Command::new("wmctrl")
            .args(["-l", "-p"])
            .output()
            .map_err(|e| PeekabooError::system_error(format!("Failed to run wmctrl: {}", e)))?;
            
        if !output.status.success() {
            return Err(PeekabooError::system_error("wmctrl command failed".to_string()));
        }
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut windows = Vec::new();
        
        for (index, line) in stdout.lines().enumerate() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 4 {
                if let Ok(window_pid) = parts[2].parse::<i32>() {
                    if window_pid == pid {
                        let window_id = u32::from_str_radix(parts[0].trim_start_matches("0x"), 16)
                            .unwrap_or(0);
                        let title = parts[4..].join(" ");
                        
                        // Get window geometry
                        let bounds = self.get_window_bounds(window_id).unwrap_or_else(|_| {
                            WindowBounds::new(0, 0, 800, 600)
                        });
                        
                        windows.push(WindowData {
                            window_id,
                            title,
                            bounds,
                            is_on_screen: true, // wmctrl only shows visible windows
                            window_index: index as i32,
                        });
                    }
                }
            }
        }
        
        Ok(windows)
    }
    
    fn get_window_bounds(&self, window_id: u32) -> PeekabooResult<WindowBounds> {
        let output = Command::new("xwininfo")
            .args(["-id", &format!("0x{:x}", window_id)])
            .output()
            .map_err(|e| PeekabooError::system_error(format!("Failed to run xwininfo: {}", e)))?;
            
        if !output.status.success() {
            return Err(PeekabooError::system_error("xwininfo command failed".to_string()));
        }
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut x = 0;
        let mut y = 0;
        let mut width = 800;
        let mut height = 600;
        
        for line in stdout.lines() {
            if line.contains("Absolute upper-left X:") {
                if let Some(value) = line.split(':').nth(1) {
                    x = value.trim().parse().unwrap_or(0);
                }
            } else if line.contains("Absolute upper-left Y:") {
                if let Some(value) = line.split(':').nth(1) {
                    y = value.trim().parse().unwrap_or(0);
                }
            } else if line.contains("Width:") {
                if let Some(value) = line.split(':').nth(1) {
                    width = value.trim().parse().unwrap_or(800);
                }
            } else if line.contains("Height:") {
                if let Some(value) = line.split(':').nth(1) {
                    height = value.trim().parse().unwrap_or(600);
                }
            }
        }
        
        Ok(WindowBounds::new(x, y, width, height))
    }
}

impl WindowManager for LinuxWindowManager {
    fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>> {
        match self.display_server {
            DisplayServer::X11 => self.get_windows_via_wmctrl(pid),
            DisplayServer::Wayland => {
                // For Wayland, we'll need to use different tools or APIs
                // For now, return empty list with a warning
                crate::logger::warn("Wayland window enumeration not fully implemented yet");
                Ok(Vec::new())
            }
            DisplayServer::Unknown => {
                Err(PeekabooError::system_error("Unknown display server".to_string()))
            }
        }
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
        let output = Command::new("wmctrl")
            .args(["-i", "-a", &format!("0x{:x}", window_id)])
            .output()
            .map_err(|e| PeekabooError::system_error(format!("Failed to activate window: {}", e)))?;
            
        if output.status.success() {
            Ok(())
        } else {
            Err(PeekabooError::system_error("Failed to activate window".to_string()))
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

/// Linux-specific application finder
pub struct LinuxApplicationFinder;

impl LinuxApplicationFinder {
    pub fn new() -> PeekabooResult<Self> {
        Ok(Self)
    }
    
    fn get_process_info(&self, pid: i32) -> PeekabooResult<(String, String)> {
        let cmdline_path = format!("/proc/{}/cmdline", pid);
        let comm_path = format!("/proc/{}/comm", pid);
        
        let name = fs::read_to_string(&comm_path)
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| format!("Process {}", pid));
            
        let cmdline = fs::read_to_string(&cmdline_path)
            .unwrap_or_else(|_| String::new());
            
        // Try to extract a meaningful application name
        let app_name = if !cmdline.is_empty() {
            let parts: Vec<&str> = cmdline.split('\0').collect();
            if let Some(first_part) = parts.first() {
                Path::new(first_part)
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or(&name)
                    .to_string()
            } else {
                name.clone()
            }
        } else {
            name.clone()
        };
        
        Ok((app_name, name))
    }
}

impl ApplicationFinder for LinuxApplicationFinder {
    fn get_all_running_applications(&self) -> PeekabooResult<Vec<ApplicationInfo>> {
        let mut applications = Vec::new();
        let mut seen_names = HashMap::new();
        
        // Read /proc to get all processes
        let proc_dir = fs::read_dir("/proc")
            .map_err(|e| PeekabooError::system_error(format!("Failed to read /proc: {}", e)))?;
            
        for entry in proc_dir {
            if let Ok(entry) = entry {
                if let Ok(pid) = entry.file_name().to_string_lossy().parse::<i32>() {
                    if let Ok((app_name, _)) = self.get_process_info(pid) {
                        // Skip kernel threads and system processes
                        if app_name.starts_with('[') && app_name.ends_with(']') {
                            continue;
                        }
                        
                        // Group by application name to avoid duplicates
                        let entry = seen_names.entry(app_name.clone()).or_insert_with(|| {
                            ApplicationInfo {
                                app_name: app_name.clone(),
                                bundle_id: format!("linux.{}", app_name),
                                pid,
                                is_active: false, // We'll determine this later
                                window_count: 0,
                            }
                        });
                        
                        // Update window count
                        if let Ok(windows) = self.get_window_count(pid) {
                            entry.window_count += windows;
                        }
                    }
                }
            }
        }
        
        applications.extend(seen_names.into_values());
        
        // Sort by name for consistent output
        applications.sort_by(|a, b| a.app_name.cmp(&b.app_name));
        
        Ok(applications)
    }
    
    fn find_application(&self, identifier: &str) -> PeekabooResult<ApplicationInfo> {
        // Try to parse as PID first
        if let Ok(pid) = identifier.parse::<i32>() {
            if let Ok((app_name, _)) = self.get_process_info(pid) {
                let window_count = self.get_window_count(pid).unwrap_or(0);
                return Ok(ApplicationInfo {
                    app_name,
                    bundle_id: format!("linux.pid.{}", pid),
                    pid,
                    is_active: self.is_application_active(pid).unwrap_or(false),
                    window_count,
                });
            }
        }
        
        // Search by name
        let applications = self.get_all_running_applications()?;
        for app in applications {
            if app.app_name.to_lowercase().contains(&identifier.to_lowercase()) ||
               app.bundle_id.to_lowercase().contains(&identifier.to_lowercase()) {
                return Ok(app);
            }
        }
        
        Err(PeekabooError::WindowNotFound)
    }
    
    fn is_application_active(&self, _pid: i32) -> PeekabooResult<bool> {
        // On Linux, determining if an application is "active" is complex
        // For now, we'll return false and implement this later
        Ok(false)
    }
    
    fn get_window_count(&self, pid: i32) -> PeekabooResult<i32> {
        let window_manager = LinuxWindowManager::new()?;
        let windows = window_manager.get_windows_for_app(pid)?;
        Ok(windows.len() as i32)
    }
}

/// Linux-specific screen capture
pub struct LinuxScreenCapture;

impl LinuxScreenCapture {
    pub fn new() -> PeekabooResult<Self> {
        Ok(Self)
    }
}

impl ScreenCapture for LinuxScreenCapture {
    fn capture_screen(&self, screen_index: Option<i32>, output_path: &str) -> PeekabooResult<String> {
        let mut cmd = Command::new("gnome-screenshot");
        cmd.arg("-f").arg(output_path);
        
        if let Some(_index) = screen_index {
            // gnome-screenshot doesn't support specific screen selection easily
            // We could use other tools like scrot or import (ImageMagick)
            crate::logger::warn("Screen index selection not implemented for gnome-screenshot");
        }
        
        let output = cmd.output()
            .map_err(|e| PeekabooError::system_error(format!("Failed to run gnome-screenshot: {}", e)))?;
            
        if output.status.success() {
            Ok(output_path.to_string())
        } else {
            // Try alternative screenshot tools
            self.capture_screen_fallback(output_path)
        }
    }
    
    fn capture_window(&self, _window_data: &WindowData, output_path: &str) -> PeekabooResult<String> {
        let output = Command::new("gnome-screenshot")
            .args(["-w", "-f", output_path])
            .output()
            .map_err(|e| PeekabooError::system_error(format!("Failed to capture window: {}", e)))?;
            
        if output.status.success() {
            Ok(output_path.to_string())
        } else {
            Err(PeekabooError::system_error("Window capture failed".to_string()))
        }
    }
    
    fn get_available_screens(&self) -> PeekabooResult<Vec<ScreenInfo>> {
        // Use xrandr to get screen information
        let output = Command::new("xrandr")
            .arg("--query")
            .output()
            .map_err(|e| PeekabooError::system_error(format!("Failed to run xrandr: {}", e)))?;
            
        if !output.status.success() {
            return Ok(vec![ScreenInfo {
                index: 0,
                width: 1920,
                height: 1080,
                is_primary: true,
            }]);
        }
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut screens = Vec::new();
        let mut index = 0;
        
        for line in stdout.lines() {
            if line.contains(" connected") {
                if let Some(resolution_part) = line.split_whitespace().nth(2) {
                    if let Some(dimensions) = resolution_part.split('+').next() {
                        if let Some((width_str, height_str)) = dimensions.split_once('x') {
                            if let (Ok(width), Ok(height)) = (width_str.parse::<i32>(), height_str.parse::<i32>()) {
                                screens.push(ScreenInfo {
                                    index,
                                    width,
                                    height,
                                    is_primary: line.contains("primary"),
                                });
                                index += 1;
                            }
                        }
                    }
                }
            }
        }
        
        if screens.is_empty() {
            screens.push(ScreenInfo {
                index: 0,
                width: 1920,
                height: 1080,
                is_primary: true,
            });
        }
        
        Ok(screens)
    }
}

impl LinuxScreenCapture {
    fn capture_screen_fallback(&self, output_path: &str) -> PeekabooResult<String> {
        // Try scrot as fallback
        let output = Command::new("scrot")
            .arg(output_path)
            .output();
            
        if let Ok(output) = output {
            if output.status.success() {
                return Ok(output_path.to_string());
            }
        }
        
        // Try import (ImageMagick) as another fallback
        let output = Command::new("import")
            .args(["-window", "root", output_path])
            .output();
            
        if let Ok(output) = output {
            if output.status.success() {
                return Ok(output_path.to_string());
            }
        }
        
        Err(PeekabooError::system_error("No suitable screenshot tool found".to_string()))
    }
}

/// Linux-specific permission checker
pub struct LinuxPermissionChecker;

impl LinuxPermissionChecker {
    pub fn new() -> Self {
        Self
    }
}

impl PermissionChecker for LinuxPermissionChecker {
    fn check_screen_recording_permission(&self) -> PeekabooResult<bool> {
        // On Linux, screen recording permissions are generally not as restrictive as macOS
        // Check if we can access display
        let has_display = std::env::var("DISPLAY").is_ok() || std::env::var("WAYLAND_DISPLAY").is_ok();
        Ok(has_display)
    }
    
    fn check_accessibility_permission(&self) -> PeekabooResult<bool> {
        // Check if we can run window management tools
        let wmctrl_available = Command::new("wmctrl")
            .arg("--version")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);
            
        Ok(wmctrl_available)
    }
    
    fn request_screen_recording_permission(&self) -> PeekabooResult<()> {
        // On Linux, permissions are typically handled at the system level
        // We can provide guidance but can't programmatically request permissions
        crate::logger::info("Screen recording permissions on Linux are typically managed by the desktop environment");
        Ok(())
    }
    
    fn request_accessibility_permission(&self) -> PeekabooResult<()> {
        crate::logger::info("Window management tools may need to be installed (wmctrl, xwininfo, etc.)");
        Ok(())
    }
}

/// Detect the current display server
fn detect_display_server() -> DisplayServer {
    if std::env::var("WAYLAND_DISPLAY").is_ok() {
        DisplayServer::Wayland
    } else if std::env::var("DISPLAY").is_ok() {
        DisplayServer::X11
    } else {
        DisplayServer::Unknown
    }
}
