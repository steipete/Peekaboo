use peekaboo::models::*;
use peekaboo::errors::*;
use peekaboo::utils::file_utils;

#[test]
fn test_image_format_extension() {
    assert_eq!(ImageFormat::Png.extension(), "png");
    assert_eq!(ImageFormat::Jpg.extension(), "jpg");
}

#[test]
fn test_capture_mode_values() {
    // Test that all capture modes can be created
    let _screen = CaptureMode::Screen;
    let _window = CaptureMode::Window;
    let _multi = CaptureMode::Multi;
}

#[test]
fn test_capture_focus_values() {
    // Test that all capture focus values can be created
    let _background = CaptureFocus::Background;
    let _auto = CaptureFocus::Auto;
    let _foreground = CaptureFocus::Foreground;
}

#[test]
fn test_window_bounds_creation() {
    let bounds = WindowBounds {
        x_coordinate: 100,
        y_coordinate: 200,
        width: 800,
        height: 600,
    };
    
    assert_eq!(bounds.x_coordinate, 100);
    assert_eq!(bounds.y_coordinate, 200);
    assert_eq!(bounds.width, 800);
    assert_eq!(bounds.height, 600);
}

#[test]
fn test_window_data_creation() {
    let bounds = WindowBounds {
        x_coordinate: 0,
        y_coordinate: 0,
        width: 1920,
        height: 1080,
    };
    
    let window = WindowData {
        window_id: 12345,
        title: "Test Window".to_string(),
        bounds,
        is_on_screen: true,
        window_index: 0,
    };
    
    assert_eq!(window.window_id, 12345);
    assert_eq!(window.title, "Test Window");
    assert!(window.is_on_screen);
    assert_eq!(window.window_index, 0);
}

#[test]
fn test_application_info_creation() {
    let app = ApplicationInfo {
        app_name: "TestApp".to_string(),
        bundle_id: "com.test.app".to_string(),
        pid: 1234,
        is_active: true,
        window_count: 2,
    };
    
    assert_eq!(app.app_name, "TestApp");
    assert_eq!(app.bundle_id, "com.test.app");
    assert_eq!(app.pid, 1234);
    assert!(app.is_active);
    assert_eq!(app.window_count, 2);
}

#[test]
fn test_server_permissions_creation() {
    let permissions = ServerPermissions {
        screen_recording: true,
        accessibility: false,
    };
    
    assert!(permissions.screen_recording);
    assert!(!permissions.accessibility);
}

#[test]
fn test_server_status_creation() {
    let permissions = ServerPermissions {
        screen_recording: true,
        accessibility: true,
    };
    
    let status = ServerStatus {
        permissions,
        platform: "Linux".to_string(),
        version: "1.0.0".to_string(),
    };
    
    assert_eq!(status.platform, "Linux");
    assert_eq!(status.version, "1.0.0");
    assert!(status.permissions.screen_recording);
    assert!(status.permissions.accessibility);
}

#[test]
fn test_peekaboo_error_creation() {
    let error = PeekabooError::ScreenRecordingPermissionDenied;
    assert!(matches!(error, PeekabooError::ScreenRecordingPermissionDenied));
    
    let error = PeekabooError::UnknownError("test error".to_string());
    assert!(matches!(error, PeekabooError::UnknownError(_)));
}

#[test]
fn test_file_utils_join_path() {
    let result = file_utils::join_path("/tmp", "test.png");
    assert_eq!(result, "/tmp/test.png");
    
    let result = file_utils::join_path("/tmp/", "test.png");
    assert_eq!(result, "/tmp/test.png");
    
    let result = file_utils::join_path("", "test.png");
    assert_eq!(result, "test.png");
}

#[test]
fn test_file_utils_sanitize_filename() {
    let result = file_utils::sanitize_filename("test file.png");
    assert_eq!(result, "test file.png");
    
    let result = file_utils::sanitize_filename("test*file?.png");
    assert_eq!(result, "test_file_.png");
    
    let result = file_utils::sanitize_filename("test/file\\name.png");
    assert_eq!(result, "test_file_name.png");
}

#[test]
fn test_clone_implementations() {
    // Test that all our structs implement Clone properly
    let format = ImageFormat::Png;
    let _cloned = format.clone();
    
    let mode = CaptureMode::Screen;
    let _cloned = mode.clone();
    
    let focus = CaptureFocus::Auto;
    let _cloned = focus.clone();
    
    let bounds = WindowBounds { x_coordinate: 0, y_coordinate: 0, width: 100, height: 100 };
    let _cloned = bounds.clone();
    
    let permissions = ServerPermissions {
        screen_recording: true,
        accessibility: false,
    };
    let _cloned = permissions.clone();
}

#[test]
fn test_debug_implementations() {
    // Test that all our structs implement Debug properly
    let format = ImageFormat::Png;
    let debug_str = format!("{:?}", format);
    assert!(debug_str.contains("Png"));
    
    let bounds = WindowBounds { x_coordinate: 0, y_coordinate: 0, width: 100, height: 100 };
    let debug_str = format!("{:?}", bounds);
    assert!(debug_str.contains("100"));
}
