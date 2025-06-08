use std::env;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
pub enum DisplayServer {
    X11,
    Wayland,
    Unknown,
}

#[derive(Debug, Clone, PartialEq)]
pub enum DesktopEnvironment {
    Gnome,
    Kde,
    Xfce,
    I3,
    Sway,
    Unity,
    Mate,
    Cinnamon,
    Lxde,
    Lxqt,
    Unknown,
}

#[derive(Debug, Clone)]
pub struct EnvironmentInfo {
    pub display_server: DisplayServer,
    pub desktop_environment: DesktopEnvironment,
    pub session_type: Option<String>,
    pub display_name: Option<String>,
    pub wayland_display: Option<String>,
    pub is_sandboxed: bool,
    pub user_id: u32,
    pub runtime_dir: Option<String>,
}

pub struct Environment;

impl Environment {
    pub fn detect() -> EnvironmentInfo {
        EnvironmentInfo {
            display_server: Self::detect_display_server(),
            desktop_environment: Self::detect_desktop_environment(),
            session_type: env::var("XDG_SESSION_TYPE").ok(),
            display_name: env::var("DISPLAY").ok(),
            wayland_display: env::var("WAYLAND_DISPLAY").ok(),
            is_sandboxed: Self::is_sandboxed(),
            user_id: Self::get_user_id(),
            runtime_dir: env::var("XDG_RUNTIME_DIR").ok(),
        }
    }

    fn detect_display_server() -> DisplayServer {
        // Check for Wayland first (more modern)
        if env::var("WAYLAND_DISPLAY").is_ok() {
            return DisplayServer::Wayland;
        }

        // Check for X11
        if env::var("DISPLAY").is_ok() {
            return DisplayServer::X11;
        }

        // Check session type as fallback
        if let Ok(session_type) = env::var("XDG_SESSION_TYPE") {
            match session_type.to_lowercase().as_str() {
                "wayland" => return DisplayServer::Wayland,
                "x11" => return DisplayServer::X11,
                _ => {}
            }
        }

        DisplayServer::Unknown
    }

    fn detect_desktop_environment() -> DesktopEnvironment {
        // Check XDG_CURRENT_DESKTOP first (most reliable)
        if let Ok(desktop) = env::var("XDG_CURRENT_DESKTOP") {
            let desktop_lower = desktop.to_lowercase();
            
            if desktop_lower.contains("gnome") {
                return DesktopEnvironment::Gnome;
            } else if desktop_lower.contains("kde") || desktop_lower.contains("plasma") {
                return DesktopEnvironment::Kde;
            } else if desktop_lower.contains("xfce") {
                return DesktopEnvironment::Xfce;
            } else if desktop_lower.contains("i3") {
                return DesktopEnvironment::I3;
            } else if desktop_lower.contains("sway") {
                return DesktopEnvironment::Sway;
            } else if desktop_lower.contains("unity") {
                return DesktopEnvironment::Unity;
            } else if desktop_lower.contains("mate") {
                return DesktopEnvironment::Mate;
            } else if desktop_lower.contains("cinnamon") {
                return DesktopEnvironment::Cinnamon;
            } else if desktop_lower.contains("lxde") {
                return DesktopEnvironment::Lxde;
            } else if desktop_lower.contains("lxqt") {
                return DesktopEnvironment::Lxqt;
            }
        }

        // Fallback checks using other environment variables
        if env::var("GNOME_DESKTOP_SESSION_ID").is_ok() || env::var("GNOME_SHELL_SESSION_MODE").is_ok() {
            return DesktopEnvironment::Gnome;
        }

        if env::var("KDE_FULL_SESSION").is_ok() || env::var("KDE_SESSION_VERSION").is_ok() {
            return DesktopEnvironment::Kde;
        }

        if env::var("DESKTOP_SESSION").as_ref().map(|s| s.contains("xfce")).unwrap_or(false) {
            return DesktopEnvironment::Xfce;
        }

        // Check for window manager processes
        if Self::is_process_running("i3") {
            return DesktopEnvironment::I3;
        }

        if Self::is_process_running("sway") {
            return DesktopEnvironment::Sway;
        }

        DesktopEnvironment::Unknown
    }

    fn is_sandboxed() -> bool {
        // Check for various sandboxing technologies
        env::var("FLATPAK_ID").is_ok() ||
        env::var("SNAP").is_ok() ||
        env::var("APPIMAGE").is_ok() ||
        Path::new("/.dockerenv").exists() ||
        Path::new("/run/.containerenv").exists()
    }

    fn get_user_id() -> u32 {
        unsafe { libc::getuid() }
    }

    fn is_process_running(process_name: &str) -> bool {
        // Check if a process is running by looking in /proc
        if let Ok(entries) = fs::read_dir("/proc") {
            for entry in entries.flatten() {
                if let Ok(file_name) = entry.file_name().into_string() {
                    if let Ok(_pid) = file_name.parse::<u32>() {
                        let comm_path = format!("/proc/{}/comm", file_name);
                        if let Ok(comm) = fs::read_to_string(comm_path) {
                            if comm.trim() == process_name {
                                return true;
                            }
                        }
                    }
                }
            }
        }
        false
    }

    pub fn get_screenshot_method(env_info: &EnvironmentInfo) -> ScreenshotMethod {
        match env_info.display_server {
            DisplayServer::X11 => ScreenshotMethod::X11,
            DisplayServer::Wayland => {
                match env_info.desktop_environment {
                    DesktopEnvironment::Gnome => ScreenshotMethod::GnomeScreenshot,
                    DesktopEnvironment::Kde => ScreenshotMethod::Spectacle,
                    DesktopEnvironment::Sway => ScreenshotMethod::Grim,
                    _ => ScreenshotMethod::WaylandGeneric,
                }
            }
            DisplayServer::Unknown => ScreenshotMethod::Generic,
        }
    }

    pub fn get_window_manager_method(env_info: &EnvironmentInfo) -> WindowManagerMethod {
        match env_info.display_server {
            DisplayServer::X11 => WindowManagerMethod::X11,
            DisplayServer::Wayland => {
                match env_info.desktop_environment {
                    DesktopEnvironment::Sway => WindowManagerMethod::SwayIPC,
                    DesktopEnvironment::Gnome => WindowManagerMethod::GnomeShell,
                    _ => WindowManagerMethod::WaylandGeneric,
                }
            }
            DisplayServer::Unknown => WindowManagerMethod::Generic,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum ScreenshotMethod {
    X11,
    GnomeScreenshot,
    Spectacle,
    Grim,
    WaylandGeneric,
    Generic,
}

#[derive(Debug, Clone, PartialEq)]
pub enum WindowManagerMethod {
    X11,
    SwayIPC,
    GnomeShell,
    WaylandGeneric,
    Generic,
}

impl std::fmt::Display for DisplayServer {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DisplayServer::X11 => write!(f, "X11"),
            DisplayServer::Wayland => write!(f, "Wayland"),
            DisplayServer::Unknown => write!(f, "Unknown"),
        }
    }
}

impl std::fmt::Display for DesktopEnvironment {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DesktopEnvironment::Gnome => write!(f, "GNOME"),
            DesktopEnvironment::Kde => write!(f, "KDE"),
            DesktopEnvironment::Xfce => write!(f, "XFCE"),
            DesktopEnvironment::I3 => write!(f, "i3"),
            DesktopEnvironment::Sway => write!(f, "Sway"),
            DesktopEnvironment::Unity => write!(f, "Unity"),
            DesktopEnvironment::Mate => write!(f, "MATE"),
            DesktopEnvironment::Cinnamon => write!(f, "Cinnamon"),
            DesktopEnvironment::Lxde => write!(f, "LXDE"),
            DesktopEnvironment::Lxqt => write!(f, "LXQt"),
            DesktopEnvironment::Unknown => write!(f, "Unknown"),
        }
    }
}

impl std::fmt::Display for EnvironmentInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Display Server: {}, Desktop Environment: {}", 
               self.display_server, self.desktop_environment)?;
        
        if let Some(session) = &self.session_type {
            write!(f, ", Session Type: {}", session)?;
        }
        
        if self.is_sandboxed {
            write!(f, ", Sandboxed: Yes")?;
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_environment_detection() {
        let env_info = Environment::detect();
        
        println!("Detected environment: {}", env_info);
        println!("Display server: {}", env_info.display_server);
        println!("Desktop environment: {}", env_info.desktop_environment);
        
        // Basic sanity checks
        assert!(env_info.user_id >= 0);
    }

    #[test]
    fn test_display_server_detection() {
        let display_server = Environment::detect_display_server();
        println!("Display server: {}", display_server);
        
        // Should detect something, even if unknown
        assert!(matches!(display_server, DisplayServer::X11 | DisplayServer::Wayland | DisplayServer::Unknown));
    }

    #[test]
    fn test_desktop_environment_detection() {
        let desktop = Environment::detect_desktop_environment();
        println!("Desktop environment: {}", desktop);
        
        // Should detect something, even if unknown
        // This is just a smoke test to ensure the function doesn't panic
    }

    #[test]
    fn test_screenshot_method_selection() {
        let env_info = Environment::detect();
        let method = Environment::get_screenshot_method(&env_info);
        
        println!("Recommended screenshot method: {:?}", method);
        
        // Should return a valid method
        assert!(matches!(method, 
            ScreenshotMethod::X11 | 
            ScreenshotMethod::GnomeScreenshot | 
            ScreenshotMethod::Spectacle | 
            ScreenshotMethod::Grim | 
            ScreenshotMethod::WaylandGeneric | 
            ScreenshotMethod::Generic
        ));
    }

    #[test]
    fn test_window_manager_method_selection() {
        let env_info = Environment::detect();
        let method = Environment::get_window_manager_method(&env_info);
        
        println!("Recommended window manager method: {:?}", method);
        
        // Should return a valid method
        assert!(matches!(method,
            WindowManagerMethod::X11 |
            WindowManagerMethod::SwayIPC |
            WindowManagerMethod::GnomeShell |
            WindowManagerMethod::WaylandGeneric |
            WindowManagerMethod::Generic
        ));
    }
}

