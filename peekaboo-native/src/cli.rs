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
        // Legacy method for backward compatibility
        let platform_manager = crate::platform::PlatformManager::new()?;
        self.execute_with_platform(&platform_manager).await
    }
    
    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        crate::logger::debug("Executing image capture command");
        
        // Use the platform manager's screen capture implementation
        let _screen_capture = &platform_manager.screen_capture;
        let _application_finder = &platform_manager.application_finder;
        let _window_manager = &platform_manager.window_manager;
        
        // Implementation will be added here
        crate::logger::warn("Image capture implementation not yet complete");
        Ok(())
    }
}

impl AppsCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // Legacy method for backward compatibility
        let platform_manager = crate::platform::PlatformManager::new()?;
        self.execute_with_platform(&platform_manager).await
    }
    
    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        crate::logger::debug("Executing apps list command");
        
        let application_finder = &platform_manager.application_finder;
        let _applications = application_finder.get_all_running_applications()?;
        
        // Implementation will be added here
        crate::logger::warn("Apps list implementation not yet complete");
        Ok(())
    }
}

impl WindowsCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // Legacy method for backward compatibility
        let platform_manager = crate::platform::PlatformManager::new()?;
        self.execute_with_platform(&platform_manager).await
    }
    
    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        crate::logger::debug("Executing windows list command");
        
        let _application_finder = &platform_manager.application_finder;
        let _window_manager = &platform_manager.window_manager;
        
        // Implementation will be added here
        crate::logger::warn("Windows list implementation not yet complete");
        Ok(())
    }
}

impl ServerStatusCommand {
    pub async fn execute(&self) -> PeekabooResult<()> {
        // Legacy method for backward compatibility
        let platform_manager = crate::platform::PlatformManager::new()?;
        self.execute_with_platform(&platform_manager).await
    }
    
    pub async fn execute_with_platform(&self, platform_manager: &crate::platform::PlatformManager) -> PeekabooResult<()> {
        crate::logger::debug("Executing server status command");
        
        let permission_checker = &platform_manager.permission_checker;
        let _screen_recording_ok = permission_checker.check_screen_recording_permission()?;
        let _accessibility_ok = permission_checker.check_accessibility_permission()?;
        
        // Implementation will be added here
        crate::logger::warn("Server status implementation not yet complete");
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
