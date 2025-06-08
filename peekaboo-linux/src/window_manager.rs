use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{WindowData, WindowInfo, WindowBounds, WindowDetailOption};
use std::collections::HashSet;

pub struct WindowManager;

impl WindowManager {
    pub fn new() -> Self {
        Self
    }

    pub fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>> {
        crate::logger::debug(&format!("Getting windows for app with PID: {}", pid));
        
        // This is a placeholder implementation
        // In a real implementation, we would use X11 or Wayland APIs
        // to enumerate windows for the specific process
        
        // For now, return a mock window to demonstrate the structure
        let mock_window = WindowData {
            window_id: 12345,
            title: "Mock Window".to_string(),
            bounds: WindowBounds::new(100, 100, 800, 600),
            is_on_screen: true,
            window_index: 0,
        };

        Ok(vec![mock_window])
    }

    pub fn get_windows_info_for_app(
        &self,
        pid: i32,
        include_off_screen: bool,
        include_bounds: bool,
        include_ids: bool,
    ) -> PeekabooResult<Vec<WindowInfo>> {
        let windows = self.get_windows_for_app(pid)?;
        let mut window_infos = Vec::new();

        for (index, window) in windows.iter().enumerate() {
            // Filter off-screen windows if not requested
            if !include_off_screen && !window.is_on_screen {
                continue;
            }

            let window_info = WindowInfo {
                window_title: window.title.clone(),
                window_id: if include_ids { Some(window.window_id) } else { None },
                window_index: Some(index as i32),
                bounds: if include_bounds { Some(window.bounds.clone()) } else { None },
                is_on_screen: Some(window.is_on_screen),
            };

            window_infos.push(window_info);
        }

        Ok(window_infos)
    }

    pub fn parse_include_details(details_string: Option<&str>) -> HashSet<WindowDetailOption> {
        let mut options = HashSet::new();
        
        if let Some(details) = details_string {
            for component in details.split(',') {
                let trimmed = component.trim();
                if let Some(option) = WindowDetailOption::from_str(trimmed) {
                    options.insert(option);
                }
            }
        }
        
        options
    }

    pub fn activate_window(&self, window_id: u32) -> PeekabooResult<()> {
        crate::logger::debug(&format!("Activating window with ID: {}", window_id));
        
        // This would use X11 or Wayland APIs to bring the window to front
        // For now, this is a placeholder
        
        Ok(())
    }

    pub fn get_window_by_title(&self, pid: i32, title: &str) -> PeekabooResult<WindowData> {
        let windows = self.get_windows_for_app(pid)?;
        
        for window in windows {
            if window.title.contains(title) {
                return Ok(window);
            }
        }
        
        Err(PeekabooError::WindowNotFound)
    }

    pub fn get_window_by_index(&self, pid: i32, index: i32) -> PeekabooResult<WindowData> {
        let windows = self.get_windows_for_app(pid)?;
        
        if index >= 0 && (index as usize) < windows.len() {
            Ok(windows[index as usize].clone())
        } else {
            Err(PeekabooError::invalid_window_index(index))
        }
    }
}

// X11-specific implementation (when X11 feature is enabled)
#[cfg(feature = "x11")]
mod x11_impl {
    use super::*;
    use x11rb::connection::Connection;
    use x11rb::protocol::xproto::*;
    use x11rb::COPY_DEPTH_FROM_PARENT;

    pub struct X11WindowManager {
        connection: Option<x11rb::rust_connection::RustConnection>,
        screen_num: usize,
    }

    impl X11WindowManager {
        pub fn new() -> PeekabooResult<Self> {
            match x11rb::connect(None) {
                Ok((conn, screen_num)) => {
                    Ok(Self {
                        connection: Some(conn),
                        screen_num,
                    })
                }
                Err(e) => {
                    crate::logger::warn(&format!("Failed to connect to X11: {}", e));
                    Ok(Self {
                        connection: None,
                        screen_num: 0,
                    })
                }
            }
        }

        pub fn get_windows_for_app(&self, pid: i32) -> PeekabooResult<Vec<WindowData>> {
            let conn = self.connection.as_ref()
                .ok_or_else(|| PeekabooError::x11_error("No X11 connection available".to_string()))?;

            let screen = &conn.setup().roots[self.screen_num];
            let root = screen.root;

            // Query all windows
            let tree_reply = conn.query_tree(root)
                .map_err(|e| PeekabooError::x11_error(format!("Failed to query window tree: {}", e)))?
                .reply()
                .map_err(|e| PeekabooError::x11_error(format!("Failed to get tree reply: {}", e)))?;

            let mut windows = Vec::new();

            for (index, &window) in tree_reply.children.iter().enumerate() {
                // Get window properties to check PID
                if let Ok(window_pid) = self.get_window_pid(conn, window) {
                    if window_pid == pid {
                        if let Ok(window_data) = self.create_window_data(conn, window, index) {
                            windows.push(window_data);
                        }
                    }
                }
            }

            Ok(windows)
        }

        fn get_window_pid(&self, conn: &x11rb::rust_connection::RustConnection, window: Window) -> Result<i32, Box<dyn std::error::Error>> {
            // Try to get _NET_WM_PID property
            let pid_atom = conn.intern_atom(false, b"_NET_WM_PID")?.reply()?.atom;
            let property = conn.get_property(false, window, pid_atom, AtomEnum::CARDINAL, 0, 1)?.reply()?;
            
            if property.value.len() >= 4 {
                let pid_bytes: [u8; 4] = property.value[0..4].try_into()?;
                let pid = u32::from_ne_bytes(pid_bytes) as i32;
                Ok(pid)
            } else {
                Err("No PID property found".into())
            }
        }

        fn create_window_data(&self, conn: &x11rb::rust_connection::RustConnection, window: Window, index: usize) -> Result<WindowData, Box<dyn std::error::Error>> {
            // Get window title
            let title = self.get_window_title(conn, window)?;
            
            // Get window geometry
            let geometry = conn.get_geometry(window)?.reply()?;
            
            // Get window attributes to check if visible
            let attributes = conn.get_window_attributes(window)?.reply()?;
            let is_on_screen = attributes.map_state == MapState::VIEWABLE;

            Ok(WindowData {
                window_id: window,
                title,
                bounds: WindowBounds::new(
                    geometry.x as i32,
                    geometry.y as i32,
                    geometry.width as i32,
                    geometry.height as i32,
                ),
                is_on_screen,
                window_index: index as i32,
            })
        }

        fn get_window_title(&self, conn: &x11rb::rust_connection::RustConnection, window: Window) -> Result<String, Box<dyn std::error::Error>> {
            // Try _NET_WM_NAME first (UTF-8)
            let name_atom = conn.intern_atom(false, b"_NET_WM_NAME")?.reply()?.atom;
            let utf8_atom = conn.intern_atom(false, b"UTF8_STRING")?.reply()?.atom;
            
            if let Ok(property) = conn.get_property(false, window, name_atom, utf8_atom, 0, 1024)?.reply() {
                if !property.value.is_empty() {
                    return Ok(String::from_utf8_lossy(&property.value).trim_end_matches('\0').to_string());
                }
            }

            // Fall back to WM_NAME
            if let Ok(property) = conn.get_property(false, window, AtomEnum::WM_NAME, AtomEnum::STRING, 0, 1024)?.reply() {
                if !property.value.is_empty() {
                    return Ok(String::from_utf8_lossy(&property.value).trim_end_matches('\0').to_string());
                }
            }

            Ok("Untitled".to_string())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_window_manager_creation() {
        let manager = WindowManager::new();
        // Just test that we can create the manager
        assert!(true);
    }

    #[test]
    fn test_parse_include_details() {
        let options = WindowManager::parse_include_details(Some("off_screen,bounds,ids"));
        assert_eq!(options.len(), 3);
        assert!(options.contains(&WindowDetailOption::OffScreen));
        assert!(options.contains(&WindowDetailOption::Bounds));
        assert!(options.contains(&WindowDetailOption::Ids));

        let empty_options = WindowManager::parse_include_details(None);
        assert!(empty_options.is_empty());

        let partial_options = WindowManager::parse_include_details(Some("bounds"));
        assert_eq!(partial_options.len(), 1);
        assert!(partial_options.contains(&WindowDetailOption::Bounds));
    }

    #[test]
    fn test_window_bounds_creation() {
        let bounds = WindowBounds::new(100, 200, 800, 600);
        assert_eq!(bounds.x_coordinate, 100);
        assert_eq!(bounds.y_coordinate, 200);
        assert_eq!(bounds.width, 800);
        assert_eq!(bounds.height, 600);
    }
}
