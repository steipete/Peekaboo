use thiserror::Error;

pub type PeekabooResult<T> = Result<T, PeekabooError>;

#[derive(Error, Debug)]
pub enum PeekabooError {
    #[error("No displays available for capture")]
    NoDisplaysAvailable,
    
    #[error("Screen recording permission is required. Please grant it in system settings")]
    ScreenRecordingPermissionDenied,
    
    #[error("Accessibility permission is required for some operations. Please grant it in system settings")]
    AccessibilityPermissionDenied,
    
    #[error("Invalid display ID provided")]
    InvalidDisplayID,
    
    #[error("Failed to create the screen capture: {0}")]
    CaptureCreationFailed(String),
    
    #[error("The specified window could not be found")]
    WindowNotFound,
    
    #[error("Window with title containing '{search_term}' not found in {app_name}. Available windows: {available_titles}. Note: For URLs, try without the protocol")]
    WindowTitleNotFound {
        search_term: String,
        app_name: String,
        available_titles: String,
    },
    
    #[error("Failed to capture the specified window: {0}")]
    WindowCaptureFailed(String),
    
    #[error("Failed to write capture file to path: {path}. {details}")]
    FileWriteError { path: String, details: String },
    
    #[error("Application with identifier '{0}' not found or is not running")]
    AppNotFound(String),
    
    #[error("Invalid window index: {0}")]
    InvalidWindowIndex(i32),
    
    #[error("Invalid argument: {0}")]
    InvalidArgument(String),
    
    #[error("An unexpected error occurred: {0}")]
    UnknownError(String),
    
    #[error("The '{app_name}' process is running, but no capturable windows were found")]
    NoWindowsFound { app_name: String },
    
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),
}

impl PeekabooError {
    pub fn exit_code(&self) -> i32 {
        match self {
            Self::NoDisplaysAvailable => 10,
            Self::ScreenRecordingPermissionDenied => 11,
            Self::AccessibilityPermissionDenied => 12,
            Self::InvalidDisplayID => 13,
            Self::CaptureCreationFailed(_) => 14,
            Self::WindowNotFound => 15,
            Self::WindowTitleNotFound { .. } => 21,
            Self::WindowCaptureFailed(_) => 16,
            Self::FileWriteError { .. } => 17,
            Self::AppNotFound(_) => 18,
            Self::InvalidWindowIndex(_) => 19,
            Self::InvalidArgument(_) => 20,
            Self::NoWindowsFound { .. } => 7,
            Self::UnknownError(_) => 1,
            Self::IoError(_) => 17,
            Self::JsonError(_) => 1,
        }
    }
    
    pub fn error_code(&self) -> &'static str {
        match self {
            Self::ScreenRecordingPermissionDenied => "PERMISSION_ERROR_SCREEN_RECORDING",
            Self::AccessibilityPermissionDenied => "PERMISSION_ERROR_ACCESSIBILITY",
            Self::AppNotFound(_) => "APP_NOT_FOUND",
            Self::WindowNotFound | Self::WindowTitleNotFound { .. } => "WINDOW_NOT_FOUND",
            Self::CaptureCreationFailed(_) | Self::WindowCaptureFailed(_) => "CAPTURE_FAILED",
            Self::FileWriteError { .. } | Self::IoError(_) => "FILE_IO_ERROR",
            Self::InvalidArgument(_) | Self::InvalidWindowIndex(_) => "INVALID_ARGUMENT",
            Self::JsonError(_) => "INTERNAL_SWIFT_ERROR",
            _ => "UNKNOWN_ERROR",
        }
    }
}

