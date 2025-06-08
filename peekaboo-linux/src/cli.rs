use clap::{Parser, Subcommand, ValueEnum};
use crate::errors::{PeekabooError, PeekabooResult};

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

#[derive(ValueEnum, Debug, Clone, Default)]
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
        use crate::screen_capture::ScreenCapture;
        use crate::permissions::PermissionsChecker;
        use crate::json_output::{output_success, JsonOutputMode};

        // Check permissions
        PermissionsChecker::require_screen_recording_permission()?;

        let capture = ScreenCapture::new();
        let mode = self.mode.as_ref().unwrap_or(&CaptureMode::Screen);

        let result = match mode {
            CaptureMode::Screen => {
                let output_path = self.path.as_deref().unwrap_or("/tmp");
                capture.capture_screens(self.screen_index, output_path, &self.format).await?
            }
            CaptureMode::Window | CaptureMode::Multi => {
                // For now, return an error as window capture is not fully implemented
                return Err(PeekabooError::invalid_argument(
                    "Window capture not yet implemented in Linux version".to_string()
                ));
            }
        };

        if JsonOutputMode::is_enabled() {
            output_success(&result, None);
        } else {
            println!("Captured {} image(s):", result.saved_files.len());
            for file in &result.saved_files {
                println!("  {}", file.path);
            }
        }

        Ok(())
    }
}

impl AppsCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        use crate::application_finder::ApplicationFinder;
        use crate::permissions::PermissionsChecker;
        use crate::json_output::{output_success, JsonOutputMode};
        use crate::models::ApplicationListData;

        // Check permissions
        PermissionsChecker::require_basic_permissions()?;

        let mut finder = ApplicationFinder::new();
        let applications = finder.get_all_running_applications()?;
        let data = ApplicationListData { applications };

        if JsonOutputMode::is_enabled() {
            output_success(&data, None);
        } else {
            println!("Running Applications ({}):", data.applications.len());
            println!();

            for (index, app) in data.applications.iter().enumerate() {
                println!("{}. {}", index + 1, app.app_name);
                println!("   Bundle ID: {}", app.bundle_id);
                println!("   PID: {}", app.pid);
                println!("   Status: {}", if app.is_active { "Active" } else { "Background" });
                println!("   Windows: {}", app.window_count);
                println!();
            }
        }

        Ok(())
    }
}

impl WindowsCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // For now, return an error as window listing is not fully implemented
        Err(PeekabooError::invalid_argument(
            "Window listing not yet implemented in Linux version".to_string()
        ))
    }
}

impl ServerStatusCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        use crate::permissions::PermissionsChecker;
        use crate::json_output::{output_success, JsonOutputMode};
        use crate::models::{ServerStatusData, ServerPermissions};

        let (screen_recording, accessibility) = PermissionsChecker::get_permission_status();
        
        let permissions = ServerPermissions {
            screen_recording,
            accessibility,
        };
        
        let data = ServerStatusData { permissions };

        if JsonOutputMode::is_enabled() {
            output_success(&data, None);
        } else {
            println!("Server Permissions Status:");
            println!("  Screen Recording: {}", if screen_recording { "✅ Granted" } else { "❌ Not granted" });
            println!("  Accessibility: {}", if accessibility { "✅ Granted" } else { "❌ Not granted" });
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
