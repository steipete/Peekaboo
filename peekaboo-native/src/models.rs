use serde::{Deserialize, Serialize};

// MARK: - Image Capture Models

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SavedFile {
    pub path: String,
    pub item_label: Option<String>,
    pub window_title: Option<String>,
    pub window_id: Option<u32>,
    pub window_index: Option<i32>,
    pub mime_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImageCaptureData {
    pub saved_files: Vec<SavedFile>,
}

// MARK: - Application & Window Models

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApplicationInfo {
    pub app_name: String,
    pub bundle_id: String,
    pub pid: i32,
    pub is_active: bool,
    pub window_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApplicationListData {
    pub applications: Vec<ApplicationInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowInfo {
    pub window_title: String,
    pub window_id: Option<u32>,
    pub window_index: Option<i32>,
    pub bounds: Option<WindowBounds>,
    pub is_on_screen: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowBounds {
    #[serde(rename = "xCoordinate")]
    pub x_coordinate: i32,
    #[serde(rename = "yCoordinate")]
    pub y_coordinate: i32,
    pub width: i32,
    pub height: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TargetApplicationInfo {
    pub app_name: String,
    pub bundle_id: Option<String>,
    pub pid: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowListData {
    pub windows: Vec<WindowInfo>,
    pub target_application_info: TargetApplicationInfo,
}

// MARK: - Server Status Models

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerPermissions {
    pub screen_recording: bool,
    pub accessibility: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerStatusData {
    pub permissions: ServerPermissions,
}

// MARK: - Window Management Internal Models

#[derive(Debug, Clone)]
pub struct WindowData {
    pub window_id: u32,
    pub title: String,
    pub bounds: WindowBounds,
    pub is_on_screen: bool,
    pub window_index: i32,
}

#[derive(Debug, Clone)]
pub struct ApplicationData {
    pub name: String,
    pub bundle_id: Option<String>,
    pub path: Option<String>,
    pub pid: i32,
    pub is_active: bool,
}

// MARK: - Window Specifier

#[derive(Debug, Clone)]
pub enum WindowSpecifier {
    Title(String),
    Index(i32),
}

// MARK: - Window Details Options

#[derive(Debug, Clone, PartialEq, Eq, Hash, clap::ValueEnum)]
pub enum WindowDetailOption {
    #[value(name = "off_screen")]
    OffScreen,
    #[value(name = "bounds")]
    Bounds,
    #[value(name = "ids")]
    Ids,
}

impl WindowDetailOption {
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "off_screen" => Some(Self::OffScreen),
            "bounds" => Some(Self::Bounds),
            "ids" => Some(Self::Ids),
            _ => None,
        }
    }
}

impl std::fmt::Display for WindowDetailOption {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::OffScreen => write!(f, "off_screen"),
            Self::Bounds => write!(f, "bounds"),
            Self::Ids => write!(f, "ids"),
        }
    }
}

// MARK: - Helper implementations

impl SavedFile {
    pub fn new(
        path: String,
        item_label: Option<String>,
        window_title: Option<String>,
        window_id: Option<u32>,
        window_index: Option<i32>,
        format: &crate::cli::ImageFormat,
    ) -> Self {
        let mime_type = match format {
            crate::cli::ImageFormat::Png => "image/png".to_string(),
            crate::cli::ImageFormat::Jpg => "image/jpeg".to_string(),
        };

        Self {
            path,
            item_label,
            window_title,
            window_id,
            window_index,
            mime_type,
        }
    }
}

impl WindowBounds {
    pub fn new(x: i32, y: i32, width: i32, height: i32) -> Self {
        Self {
            x_coordinate: x,
            y_coordinate: y,
            width,
            height,
        }
    }
}

impl From<WindowData> for WindowInfo {
    fn from(window_data: WindowData) -> Self {
        Self {
            window_title: window_data.title,
            window_id: Some(window_data.window_id),
            window_index: Some(window_data.window_index),
            bounds: Some(window_data.bounds),
            is_on_screen: Some(window_data.is_on_screen),
        }
    }
}

impl From<ApplicationData> for ApplicationInfo {
    fn from(app_data: ApplicationData) -> Self {
        Self {
            app_name: app_data.name,
            bundle_id: app_data.bundle_id.unwrap_or_default(),
            pid: app_data.pid,
            is_active: app_data.is_active,
            window_count: 0, // Will be filled in by the caller
        }
    }
}
