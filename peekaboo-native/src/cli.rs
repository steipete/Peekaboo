use clap::{Parser, Subcommand, ValueEnum};
use crate::errors::{PeekabooError, PeekabooResult};
use serde::Serialize;
use serde_json;

/// A Linux utility for screen capture, application listing, and window management
#[derive(Parser, Debug)]
#[command(name = "peekaboo")]
#[command(about = "A Linux utility for screen capture, application listing, and window management")]
#[command(version = env!("CARGO_PKG_VERSION"))]
pub struct PeekabooCommand {
    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Capture screenshots or windows
    Image(ImageCommand),
    /// List applications and windows
    #[command(subcommand)]
    List(ListCommands),
}

#[derive(Subcommand, Debug)]
pub enum ListCommands {
    /// List running applications
    Apps(AppsCommand),
    /// List windows
    Windows(WindowsCommand),
    /// Check server permissions status
    #[command(name = "server_status")]
    ServerStatus(ServerStatusCommand),
}

#[derive(Parser, Debug, Default)]
pub struct ImageCommand {
    /// Target application identifier
    #[arg(long)]
    pub app: Option<String>,

    /// Base output path for saved images
    #[arg(long)]
    pub path: Option<String>,

    /// Capture mode
    #[arg(long)]
    pub mode: Option<CaptureMode>,

    /// Window title to capture
    #[arg(long = "window-title")]
    pub window_title: Option<String>,

    /// Window index to capture (0=frontmost)
    #[arg(long = "window-index")]
    pub window_index: Option<i32>,

    /// Screen index to capture (0-based)
    #[arg(long = "screen-index")]
    pub screen_index: Option<i32>,

    /// Image format
    #[arg(long, default_value = "png")]
    pub format: ImageFormat,

    /// Capture focus behavior
    #[arg(long = "capture-focus", default_value = "auto")]
    pub capture_focus: CaptureFocus,

    /// Include additional window details
    #[arg(long, value_enum)]
    pub window_details: Vec<crate::models::WindowDetailOption>,

    /// Output results in JSON format
    #[arg(long = "json-output")]
    pub json_output: bool,
}

#[derive(Parser, Debug)]
pub struct AppsCommand {
    /// Output results in JSON format
    #[arg(long = "json-output")]
    pub json_output: bool,
}

#[derive(Parser, Debug)]
pub struct WindowsCommand {
    /// Target application identifier
    #[arg(long)]
    pub app: String,

    /// Include additional window details (comma-separated: off_screen,bounds,ids)
    #[arg(long = "include-details")]
    pub include_details: Option<String>,

    /// Output results in JSON format
    #[arg(long = "json-output")]
    pub json_output: bool,
}

#[derive(Parser, Debug)]
pub struct ServerStatusCommand {
    /// Output results in JSON format
    #[arg(long = "json-output")]
    pub json_output: bool,
}

#[derive(ValueEnum, Clone, Debug, Serialize, Default)]
pub enum CaptureMode {
    #[default]
    Screen,
    Window,
    Multi,
}

#[derive(ValueEnum, Debug, Clone, Default)]
pub enum ImageFormat {
    #[default]
    Png,
    Jpg,
}

#[derive(ValueEnum, Debug, Clone, Default)]
pub enum CaptureFocus {
    Background,
    #[default]
    Auto,
    Foreground,
}


impl ImageCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // TODO: Implement image capture functionality
        println!("Image capture not yet implemented");
        Ok(())
    }

    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        use crate::traits::ScreenCapture;
        
        let screen_capture = platform_manager.get_screen_capture()?;
        let output_file = self.path.clone().unwrap_or_else(|| "screenshot.png".to_string());
        
        // For now, just capture the screen regardless of mode
        let result = screen_capture.capture_screen(None, &output_file)?;
        
        if self.json_output {
            let data = serde_json::json!({
                "success": true,
                "file_path": result,
                "app": self.app,
                "window_title": self.window_title,
                "window_index": self.window_index,
                "mode": self.mode
            });
            println!("{}", serde_json::to_string_pretty(&data).unwrap());
        } else {
            println!("Screenshot saved to: {}", result);
        }
        Ok(())
    }
}

impl AppsCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // TODO: Implement apps listing functionality
        println!("Apps listing not yet implemented");
        Ok(())
    }

    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        use crate::traits::ApplicationFinder;
        
        let app_finder = platform_manager.get_application_finder()?;
        let apps = app_finder.get_all_running_applications()?;
        
        if self.json_output {
            let data = serde_json::json!({
                "success": true,
                "applications": apps
            });
            println!("{}", serde_json::to_string_pretty(&data).unwrap());
        } else {
            println!("Running Applications:");
            for app in apps {
                println!("  {} (PID: {})", app.app_name, app.pid);
            }
        }
        Ok(())
    }
}

impl WindowsCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // TODO: Implement windows listing functionality
        println!("Windows listing not yet implemented");
        Ok(())
    }

    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        use crate::traits::WindowManager;
        
        let window_manager = platform_manager.get_window_manager()?;
        
        // For now, just return a placeholder response
        if self.json_output {
            let data = serde_json::json!({
                "success": true,
                "windows": [],
                "message": "Window listing not yet fully implemented"
            });
            println!("{}", serde_json::to_string_pretty(&data).unwrap());
        } else {
            println!("Window listing not yet fully implemented");
        }
        Ok(())
    }
}

impl ServerStatusCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // TODO: Implement server status functionality
        println!("Server status not yet implemented");
        Ok(())
    }

    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        use crate::traits::PermissionChecker;
        
        let permission_checker = platform_manager.get_permission_checker()?;
        let has_screen_recording = permission_checker.check_screen_recording_permission().unwrap_or(false);
        let has_accessibility = permission_checker.check_accessibility_permission().unwrap_or(false);
        
        if self.json_output {
            let data = serde_json::json!({
                "success": true,
                "server_status": {
                    "platform": std::env::consts::OS,
                    "permissions": {
                        "screen_recording": has_screen_recording,
                        "accessibility": has_accessibility
                    },
                    "version": env!("CARGO_PKG_VERSION")
                }
            });
            println!("{}", serde_json::to_string_pretty(&data).unwrap());
        } else {
            println!("Server Status:");
            println!("  Platform: {}", std::env::consts::OS);
            println!("  Version: {}", env!("CARGO_PKG_VERSION"));
            println!("  Permissions:");
            println!("    Screen Recording: {}", if has_screen_recording { "✓" } else { "✗" });
            println!("    Accessibility: {}", if has_accessibility { "✓" } else { "✗" });
        }
        Ok(())
    }
}

impl std::fmt::Display for CaptureMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CaptureMode::Screen => write!(f, "screen"),
            CaptureMode::Window => write!(f, "window"),
            CaptureMode::Multi => write!(f, "multi"),
        }
    }
}

impl std::fmt::Display for ImageFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ImageFormat::Png => write!(f, "png"),
            ImageFormat::Jpg => write!(f, "jpg"),
        }
    }
}

impl std::fmt::Display for CaptureFocus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CaptureFocus::Background => write!(f, "background"),
            CaptureFocus::Auto => write!(f, "auto"),
            CaptureFocus::Foreground => write!(f, "foreground"),
        }
    }
}
