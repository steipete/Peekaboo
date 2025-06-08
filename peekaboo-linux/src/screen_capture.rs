use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{SavedFile, ImageCaptureData};
use crate::cli::ImageFormat;
use screenshots::Screen;
use image::{ImageFormat as ImageFormatEnum, DynamicImage};
use std::path::Path;

pub struct ScreenCapture;

impl ScreenCapture {
    pub fn new() -> Self {
        Self
    }

    pub async fn capture_screens(
        &self,
        screen_index: Option<i32>,
        output_path: &str,
        format: &ImageFormat,
    ) -> PeekabooResult<ImageCaptureData> {
        let screens = Screen::all().map_err(|_e| {
            PeekabooError::CaptureCreationFailed
        })?;

        if screens.is_empty() {
            return Err(PeekabooError::NoDisplaysAvailable);
        }

        let mut saved_files = Vec::new();

        if let Some(index) = screen_index {
            // Capture specific screen
            if index >= 0 && (index as usize) < screens.len() {
                let screen = &screens[index as usize];
                let file_path = self.generate_screen_filename(output_path, Some(index), format);
                self.capture_single_screen(screen, &file_path, format)?;
                
                saved_files.push(SavedFile::new(
                    file_path,
                    Some(format!("Display {} (Index {})", index + 1, index)),
                    None,
                    None,
                    None,
                    format,
                ));
            } else {
                return Err(PeekabooError::InvalidDisplayID);
            }
        } else {
            // Capture all screens
            for (index, screen) in screens.iter().enumerate() {
                let file_path = self.generate_screen_filename(output_path, Some(index as i32), format);
                self.capture_single_screen(screen, &file_path, format)?;
                
                saved_files.push(SavedFile::new(
                    file_path,
                    Some(format!("Display {}", index + 1)),
                    None,
                    None,
                    None,
                    format,
                ));
            }
        }

        Ok(ImageCaptureData { saved_files })
    }

    fn capture_single_screen(
        &self,
        screen: &Screen,
        file_path: &str,
        format: &ImageFormat,
    ) -> PeekabooResult<()> {
        let image = screen.capture().map_err(|e| {
            crate::logger::error(&format!("Failed to capture screen: {}", e));
            PeekabooError::CaptureCreationFailed
        })?;

        // Convert screenshots::Image to image::RgbaImage
        let rgba_image = image::RgbaImage::from_raw(
            image.width() as u32,
            image.height() as u32,
            image.as_raw().to_vec(),
        )
        .ok_or_else(|| PeekabooError::CaptureCreationFailed)?;

        self.save_image_buffer(&rgba_image, file_path, format)?;
        Ok(())
    }

    fn save_image_buffer(
        &self,
        image: &image::RgbaImage,
        file_path: &str,
        format: &ImageFormat,
    ) -> PeekabooResult<()> {
        // Convert to DynamicImage
        let dynamic_image = DynamicImage::ImageRgba8(image.clone());

        // Ensure parent directory exists
        if let Some(parent) = Path::new(file_path).parent() {
            std::fs::create_dir_all(parent).map_err(|e| {
                PeekabooError::file_write_error(file_path.to_string(), Some(&e))
            })?;
        }

        // Save the image
        let image_format = match format {
            ImageFormat::Png => ImageFormatEnum::Png,
            ImageFormat::Jpg => ImageFormatEnum::Jpeg,
        };

        dynamic_image.save_with_format(file_path, image_format).map_err(|e| {
            PeekabooError::file_write_error(file_path.to_string(), Some(&e))
        })?;

        crate::logger::debug(&format!("Successfully saved screen capture to: {}", file_path));
        Ok(())
    }

    fn generate_screen_filename(
        &self,
        base_path: &str,
        screen_index: Option<i32>,
        format: &ImageFormat,
    ) -> String {
        let timestamp = chrono::Local::now().format("%Y%m%d_%H%M%S").to_string();
        let ext = format.to_string();

        if base_path.contains('.') && !base_path.ends_with('/') {
            // Treat as file path
            if let Some(index) = screen_index {
                let path = Path::new(base_path);
                let stem = path.file_stem().unwrap_or_default().to_string_lossy();
                let parent = path.parent().unwrap_or_else(|| Path::new("."));
                format!("{}/{}_{}.{}", parent.display(), stem, index + 1, ext)
            } else {
                base_path.to_string()
            }
        } else {
            // Treat as directory
            if let Some(index) = screen_index {
                format!("{}/screen_{}_{}.{}", base_path.trim_end_matches('/'), index + 1, timestamp, ext)
            } else {
                format!("{}/screen_{}.{}", base_path.trim_end_matches('/'), timestamp, ext)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_generate_screen_filename() {
        let capture = ScreenCapture::new();
        let format = ImageFormat::Png;

        // Test directory path
        let result = capture.generate_screen_filename("/tmp", Some(0), &format);
        assert!(result.starts_with("/tmp/screen_1_"));
        assert!(result.ends_with(".png"));

        // Test file path
        let result = capture.generate_screen_filename("/tmp/test.png", Some(1), &format);
        assert_eq!(result, "/tmp/test_2.png");
    }

    #[tokio::test]
    async fn test_screen_enumeration() {
        let capture = ScreenCapture::new();
        
        // This test just verifies the screen enumeration doesn't crash
        // Actual capture testing would require a display server
        let screens = Screen::all();
        
        // On headless systems, this might return an error, which is expected
        match screens {
            Ok(screens) => {
                println!("Found {} screens", screens.len());
            }
            Err(e) => {
                println!("No screens available (expected in headless environment): {}", e);
            }
        }
    }
}
