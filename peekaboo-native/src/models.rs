use serde::{Deserialize, Serialize};
use clap::ValueEnum;

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

#[derive(Debug, Clone, ValueEnum, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum CaptureMode {
    Screen,
    Window,
    Multi,
}

#[derive(Debug, Clone, ValueEnum, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum ImageFormat {
    Png,
    Jpg,
}

impl ImageFormat {
    pub fn mime_type(&self) -> &'static str {
        match self {
            Self::Png => "image/png",
            Self::Jpg => "image/jpeg",
        }
    }
    
    pub fn extension(&self) -> &'static str {
        match self {
            Self::Png => "png",
            Self::Jpg => "jpg",
        }
    }
}

#[derive(Debug, Clone, ValueEnum, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum CaptureFocus {
    Background,
    Auto,
    Foreground,
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
    pub server_status: ServerStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerStatus {
    pub permissions: ServerPermissions,
    pub platform: String,
    pub version: String,
}

// MARK: - Window Details Options

#[derive(Debug, Clone, ValueEnum, PartialEq)]
#[clap(rename_all = "snake_case")]
pub enum WindowDetailOption {
    OffScreen,
    Bounds,
    Ids,
}

// MARK: - Internal Window Data

#[derive(Debug, Clone)]
pub struct WindowData {
    pub window_id: u32,
    pub title: String,
    pub bounds: WindowBounds,
    pub is_on_screen: bool,
    pub window_index: i32,
}

impl WindowData {
    pub fn to_window_info(&self, include_bounds: bool, include_ids: bool) -> WindowInfo {
        WindowInfo {
            window_title: self.title.clone(),
            window_id: if include_ids { Some(self.window_id) } else { None },
            window_index: Some(self.window_index),
            bounds: if include_bounds { Some(self.bounds.clone()) } else { None },
            is_on_screen: Some(self.is_on_screen),
        }
    }
}
