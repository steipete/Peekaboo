use thiserror::Error;

pub type PeekabooResult<T> = Result<T, PeekabooError>;

#[derive(Error, Debug)]
pub enum PeekabooError {
    #[error("No displays available for capture")]
    NoDisplaysAvailable,

    #[error("Screen recording permission is required. Please ensure your user has access to the display server and necessary permissions.")]
    ScreenRecordingPermissionDenied,

    #[error("Accessibility permission is required for some operations. Please ensure your user has necessary window management permissions.")]
    AccessibilityPermissionDenied,

    #[error("Invalid display ID provided")]
    InvalidDisplayID,

    #[error("Failed to create the screen capture")]
    CaptureCreationFailed,

    #[error("The specified window could not be found")]
    WindowNotFound,

    #[error("Failed to capture the specified window")]
    WindowCaptureFailed,

    #[error("Failed to write capture file to path: {path}. {details}")]
    FileWriteError { path: String, details: String },

    #[error("Application with identifier '{identifier}' not found or is not running")]
    AppNotFound { identifier: String },

    #[error("Invalid window index: {index}")]
    InvalidWindowIndex { index: i32 },

    #[error("Invalid argument: {message}")]
    InvalidArgument { message: String },

    #[error("An unexpected error occurred: {message}")]
    UnknownError { message: String },

    #[error("The '{app_name}' process is running, but no capturable windows were found")]
    NoWindowsFound { app_name: String },

    #[error("X11 error: {message}")]
    X11Error { message: String },

    #[error("Wayland error: {message}")]
    WaylandError { message: String },

    #[error("Environment error: {message}")]
    EnvironmentError { message: String },

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Image processing error: {0}")]
    ImageError(#[from] image::ImageError),

    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),

    #[error("System information error: {message}")]
    SystemInfoError { message: String },

    #[error("System error: {message}")]
    SystemError { message: String },

    #[error("Platform '{platform}' is not supported")]
    UnsupportedPlatform { platform: String },
}

impl PeekabooError {
    pub fn exit_code(&self) -> i32 {
        match self {
            Self::NoDisplaysAvailable => 10,
            Self::ScreenRecordingPermissionDenied => 11,
            Self::AccessibilityPermissionDenied => 12,
            Self::InvalidDisplayID => 13,
            Self::CaptureCreationFailed => 14,
            Self::WindowNotFound => 15,
            Self::WindowCaptureFailed => 16,
            Self::FileWriteError { .. } => 17,
            Self::AppNotFound { .. } => 18,
            Self::InvalidWindowIndex { .. } => 19,
            Self::InvalidArgument { .. } => 20,
            Self::NoWindowsFound { .. } => 7,
            Self::X11Error { .. } => 21,
            Self::WaylandError { .. } => 22,
            Self::EnvironmentError { .. } => 23,
            Self::IoError(_) => 24,
            Self::ImageError(_) => 25,
            Self::JsonError(_) => 26,
            Self::SystemInfoError { .. } => 27,
            Self::SystemError { .. } => 28,
            Self::UnsupportedPlatform { .. } => 29,
            Self::UnknownError { .. } => 1,
        }
    }

    pub fn error_code(&self) -> &'static str {
        match self {
            Self::NoDisplaysAvailable => "NO_DISPLAYS_AVAILABLE",
            Self::ScreenRecordingPermissionDenied => "PERMISSION_ERROR_SCREEN_RECORDING",
            Self::AccessibilityPermissionDenied => "PERMISSION_ERROR_ACCESSIBILITY",
            Self::InvalidDisplayID => "INVALID_DISPLAY_ID",
            Self::CaptureCreationFailed => "CAPTURE_CREATION_FAILED",
            Self::WindowNotFound => "WINDOW_NOT_FOUND",
            Self::WindowCaptureFailed => "WINDOW_CAPTURE_FAILED",
            Self::FileWriteError { .. } => "FILE_IO_ERROR",
            Self::AppNotFound { .. } => "APP_NOT_FOUND",
            Self::InvalidWindowIndex { .. } => "INVALID_WINDOW_INDEX",
            Self::InvalidArgument { .. } => "INVALID_ARGUMENT",
            Self::NoWindowsFound { .. } => "NO_WINDOWS_FOUND",
            Self::X11Error { .. } => "X11_ERROR",
            Self::WaylandError { .. } => "WAYLAND_ERROR",
            Self::EnvironmentError { .. } => "ENVIRONMENT_ERROR",
            Self::IoError(_) => "IO_ERROR",
            Self::ImageError(_) => "IMAGE_ERROR",
            Self::JsonError(_) => "JSON_ERROR",
            Self::SystemInfoError { .. } => "SYSTEM_INFO_ERROR",
            Self::SystemError { .. } => "SYSTEM_ERROR",
            Self::UnsupportedPlatform { .. } => "UNSUPPORTED_PLATFORM",
            Self::UnknownError { .. } => "UNKNOWN_ERROR",
        }
    }
}

// Helper functions for creating specific errors
impl PeekabooError {
    pub fn file_write_error(path: String, underlying_error: Option<&dyn std::error::Error>) -> Self {
        let details = if let Some(error) = underlying_error {
            let error_string = error.to_string().to_lowercase();
            if error_string.contains("permission") {
                "Permission denied - check that the directory is writable and the application has necessary permissions.".to_string()
            } else if error_string.contains("no such file") {
                "Directory does not exist - ensure the parent directory exists.".to_string()
            } else if error_string.contains("no space") {
                "Insufficient disk space available.".to_string()
            } else {
                error.to_string()
            }
        } else {
            "This may be due to insufficient permissions, missing directory, or disk space issues.".to_string()
        };

        Self::FileWriteError { path, details }
    }

    pub fn app_not_found(identifier: String) -> Self {
        Self::AppNotFound { identifier }
    }

    pub fn invalid_window_index(index: i32) -> Self {
        Self::InvalidWindowIndex { index }
    }

    pub fn invalid_argument(message: String) -> Self {
        Self::InvalidArgument { message }
    }

    pub fn unknown_error(message: String) -> Self {
        Self::UnknownError { message }
    }

    pub fn no_windows_found(app_name: String) -> Self {
        Self::NoWindowsFound { app_name }
    }

    pub fn x11_error(message: String) -> Self {
        Self::X11Error { message }
    }

    pub fn wayland_error(message: String) -> Self {
        Self::WaylandError { message }
    }

    pub fn environment_error(message: String) -> Self {
        Self::EnvironmentError { message }
    }

    pub fn system_info_error(message: String) -> Self {
        Self::SystemInfoError { message }
    }

    pub fn system_error(message: String) -> Self {
        Self::SystemError { message }
    }

    pub fn unsupported_platform(platform: String) -> Self {
        Self::UnsupportedPlatform { platform }
    }
}
