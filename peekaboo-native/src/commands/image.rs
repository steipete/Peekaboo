use clap::Parser;
use crate::errors::PeekabooResult;
use crate::models::{CaptureMode, ImageFormat, CaptureFocus, SavedFile, ImageCaptureData};
use crate::platform;
use crate::json_output::{self, Logger};
use crate::utils::file_utils;

#[derive(Parser, Clone)]
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
    #[arg(long)]
    pub window_title: Option<String>,

    /// Window index to capture (0=frontmost)
    #[arg(long)]
    pub window_index: Option<i32>,

    /// Screen index to capture (0-based)
    #[arg(long)]
    pub screen_index: Option<usize>,

    /// Image format
    #[arg(long, default_value = "png")]
    pub format: ImageFormat,

    /// Capture focus behavior
    #[arg(long, default_value = "auto")]
    pub capture_focus: CaptureFocus,

    /// Output results in JSON format
    #[arg(long)]
    pub json_output: bool,
}

impl Default for ImageCommand {
    fn default() -> Self {
        Self {
            app: None,
            path: None,
            mode: None,
            window_title: None,
            window_index: None,
            screen_index: None,
            format: ImageFormat::Png,
            capture_focus: CaptureFocus::Auto,
            json_output: false,
        }
    }
}

impl ImageCommand {
    pub fn execute(&self) -> PeekabooResult<()> {
        Logger::debug(&format!("Executing image command with mode: {:?}", self.determine_mode()));
        
        let mut platform = platform::get_platform()?;
        
        // Check permissions
        if !platform.check_screen_recording_permission() {
            platform.request_screen_recording_permission()?;
        }
        
        let saved_files = self.perform_capture(&mut *platform)?;
        
        if self.json_output {
            let data = ImageCaptureData { saved_files };
            json_output::output_success(data, None);
        } else {
            println!("Captured {} image(s):", saved_files.len());
            for file in &saved_files {
                println!("  {}", file.path);
            }
        }
        
        Ok(())
    }
    
    fn determine_mode(&self) -> CaptureMode {
        if let Some(mode) = &self.mode {
            mode.clone()
        } else if self.app.is_some() {
            CaptureMode::Window
        } else {
            CaptureMode::Screen
        }
    }
    
    fn perform_capture(&self, platform: &mut dyn crate::traits::Platform) -> PeekabooResult<Vec<SavedFile>> {
        let mode = self.determine_mode();
        
        match mode {
            CaptureMode::Screen => self.capture_screens(platform),
            CaptureMode::Window => {
                let app_id = self.app.as_ref()
                    .ok_or_else(|| crate::errors::PeekabooError::InvalidArgument("No application specified for window capture".to_string()))?;
                self.capture_application_window(platform, app_id)
            }
            CaptureMode::Multi => {
                if let Some(app_id) = &self.app {
                    self.capture_all_application_windows(platform, app_id)
                } else {
                    self.capture_screens(platform)
                }
            }
        }
    }
    
    fn capture_screens(&self, platform: &mut dyn crate::traits::Platform) -> PeekabooResult<Vec<SavedFile>> {
        let mut saved_files = Vec::new();
        
        if let Some(screen_index) = self.screen_index {
            // Capture specific screen
            let output_path = self.generate_screen_output_path(screen_index);
            platform.capture_display(screen_index, &output_path, self.format.clone())?;
            
            saved_files.push(SavedFile {
                path: output_path,
                item_label: Some(format!("Display {} (Index {})", screen_index + 1, screen_index)),
                window_title: None,
                window_id: None,
                window_index: None,
                mime_type: self.format.mime_type().to_string(),
            });
        } else {
            // Capture all screens
            let display_count = platform.get_display_count()?;
            for i in 0..display_count {
                let output_path = self.generate_screen_output_path(i);
                platform.capture_display(i, &output_path, self.format.clone())?;
                
                saved_files.push(SavedFile {
                    path: output_path,
                    item_label: Some(format!("Display {}", i + 1)),
                    window_title: None,
                    window_id: None,
                    window_index: None,
                    mime_type: self.format.mime_type().to_string(),
                });
            }
        }
        
        Ok(saved_files)
    }
    
    fn capture_application_window(&self, platform: &mut dyn crate::traits::Platform, app_id: &str) -> PeekabooResult<Vec<SavedFile>> {
        let app = platform.find_application(app_id)?;
        
        // Handle focus behavior
        if matches!(self.capture_focus, CaptureFocus::Foreground) || 
           (matches!(self.capture_focus, CaptureFocus::Auto) && !platform.is_application_active(&app)?) {
            if !platform.check_accessibility_permission() {
                platform.request_accessibility_permission()?;
            }
            platform.activate_application(&app)?;
            std::thread::sleep(std::time::Duration::from_millis(200));
        }
        
        let windows = platform.get_windows_for_app(app.pid)?;
        if windows.is_empty() {
            return Err(crate::errors::PeekabooError::NoWindowsFound { 
                app_name: app.app_name 
            });
        }
        
        let target_window = if let Some(window_title) = &self.window_title {
            platform.find_window_by_title(app.pid, window_title)?
        } else if let Some(window_index) = self.window_index {
            platform.get_window_by_index(app.pid, window_index)?
        } else {
            windows[0].clone() // frontmost window
        };
        
        let output_path = self.generate_window_output_path(&app.app_name, &target_window.title);
        platform.capture_window(&target_window, &output_path, self.format.clone())?;
        
        let saved_file = SavedFile {
            path: output_path,
            item_label: Some(app.app_name),
            window_title: Some(target_window.title),
            window_id: Some(target_window.window_id),
            window_index: Some(target_window.window_index),
            mime_type: self.format.mime_type().to_string(),
        };
        
        Ok(vec![saved_file])
    }
    
    fn capture_all_application_windows(&self, platform: &mut dyn crate::traits::Platform, app_id: &str) -> PeekabooResult<Vec<SavedFile>> {
        let app = platform.find_application(app_id)?;
        
        // Handle focus behavior
        if matches!(self.capture_focus, CaptureFocus::Foreground) || 
           (matches!(self.capture_focus, CaptureFocus::Auto) && !platform.is_application_active(&app)?) {
            if !platform.check_accessibility_permission() {
                platform.request_accessibility_permission()?;
            }
            platform.activate_application(&app)?;
            std::thread::sleep(std::time::Duration::from_millis(200));
        }
        
        let windows = platform.get_windows_for_app(app.pid)?;
        if windows.is_empty() {
            return Err(crate::errors::PeekabooError::NoWindowsFound { 
                app_name: app.app_name 
            });
        }
        
        let mut saved_files = Vec::new();
        
        for (index, window) in windows.iter().enumerate() {
            let output_path = self.generate_window_output_path_with_index(&app.app_name, index, &window.title);
            platform.capture_window(window, &output_path, self.format.clone())?;
            
            saved_files.push(SavedFile {
                path: output_path,
                item_label: Some(app.app_name.clone()),
                window_title: Some(window.title.clone()),
                window_id: Some(window.window_id),
                window_index: Some(index as i32),
                mime_type: self.format.mime_type().to_string(),
            });
        }
        
        Ok(saved_files)
    }
    
    fn generate_screen_output_path(&self, display_index: usize) -> String {
        let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S");
        let filename = format!("screenshot_display_{}_{}.{}", display_index, timestamp, self.format.extension());
        
        if let Some(base_path) = &self.path {
            file_utils::join_path(base_path, &filename)
        } else {
            filename
        }
    }
    
    fn generate_window_output_path(&self, app_name: &str, window_title: &str) -> String {
        let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S");
        let safe_app_name = file_utils::sanitize_filename(app_name);
        let safe_window_title = file_utils::sanitize_filename(window_title);
        let filename = format!("{}_{}_window_{}.{}", safe_app_name, safe_window_title, timestamp, self.format.extension());
        
        if let Some(base_path) = &self.path {
            file_utils::join_path(base_path, &filename)
        } else {
            filename
        }
    }
    
    fn generate_window_output_path_with_index(&self, app_name: &str, index: usize, window_title: &str) -> String {
        let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S");
        let safe_app_name = file_utils::sanitize_filename(app_name);
        let safe_window_title = file_utils::sanitize_filename(window_title);
        let filename = format!("{}_window_{}_{}_{}_{}.{}", 
                              safe_app_name, index, safe_window_title, timestamp, 
                              uuid::Uuid::new_v4().to_string()[..8].to_string(), 
                              self.format.extension());
        
        if let Some(base_path) = &self.path {
            file_utils::join_path(base_path, &filename)
        } else {
            filename
        }
    }
}
