use crate::errors::{PeekabooError, PeekabooResult};
use crate::models::{ApplicationData, ApplicationInfo};
use sysinfo::{System, Pid};
use std::collections::HashMap;

#[cfg(windows)]
use winapi::um::{
    processthreadsapi::OpenProcess,
    psapi::{GetModuleFileNameExW, GetProcessImageFileNameW},
    winnt::{PROCESS_QUERY_INFORMATION, PROCESS_VM_READ},
    handleapi::CloseHandle,
    tlhelp32api::{CreateToolhelp32Snapshot, Process32FirstW, Process32NextW, TH32CS_SNAPPROCESS},
    winuser::{GetWindowTextW, EnumWindows, GetWindowThreadProcessId, IsWindowVisible},
};

#[cfg(windows)]
use std::ffi::OsString;
#[cfg(windows)]
use std::os::windows::ffi::OsStringExt;

pub struct ApplicationFinder {
    system: System,
}

#[derive(Debug, Clone)]
pub struct AppMatch {
    pub app: ApplicationData,
    pub score: f64,
    pub match_type: String,
}

impl ApplicationFinder {
    pub fn new() -> Self {
        let mut system = System::new_all();
        system.refresh_all();
        Self { system }
    }

    pub fn refresh(&mut self) {
        self.system.refresh_all();
    }

    pub fn find_application(&mut self, identifier: &str) -> PeekabooResult<ApplicationData> {
        crate::logger::debug(&format!("Searching for application: {}", identifier));

        self.refresh();
        let running_apps = self.get_all_running_applications_internal()?;

        // Check for exact name match first
        if let Some(exact_match) = running_apps.iter().find(|app| {
            app.name.to_lowercase() == identifier.to_lowercase()
        }) {
            crate::logger::debug(&format!("Found exact name match: {}", exact_match.name));
            return Ok(exact_match.clone());
        }

        // Check for exact bundle ID match (if it looks like a bundle ID)
        if identifier.contains('.') {
            if let Some(bundle_match) = running_apps.iter().find(|app| {
                app.bundle_id.as_ref().map_or(false, |id| id == identifier)
            }) {
                crate::logger::debug(&format!("Found exact bundle ID match: {}", bundle_match.name));
                return Ok(bundle_match.clone());
            }
        }

        // Find all possible matches
        let matches = self.find_all_matches(identifier, &running_apps);
        let unique_matches = self.remove_duplicate_matches(matches);

        self.process_match_results(unique_matches, identifier, &running_apps)
    }

    pub fn get_all_running_applications(&mut self) -> PeekabooResult<Vec<ApplicationInfo>> {
        crate::logger::debug("Retrieving all running applications");
        
        self.refresh();
        let apps = self.get_all_running_applications_internal()?;
        
        let mut result = Vec::new();
        for app in apps {
            // Count windows for this app (simplified for now)
            let window_count = self.count_windows_for_app(app.pid);
            
            // Only include applications that have one or more windows
            if window_count > 0 {
                let mut app_info: ApplicationInfo = app.into();
                app_info.window_count = window_count;
                result.push(app_info);
            }
        }

        // Sort by name for consistent output
        result.sort_by(|a, b| a.app_name.to_lowercase().cmp(&b.app_name.to_lowercase()));

        crate::logger::debug(&format!("Found {} running applications with windows", result.len()));
        Ok(result)
    }

    fn get_all_running_applications_internal(&mut self) -> PeekabooResult<Vec<ApplicationData>> {
        #[cfg(windows)]
        {
            return self.get_windows_applications();
        }
        
        #[cfg(not(windows))]
        {
            let mut apps = Vec::new();
            let mut seen_names = HashMap::new();

            for (pid, process) in self.system.processes() {
                let process_name = process.name().to_string_lossy();
                
                // Skip system processes and processes without names
                if process_name.is_empty() || self.is_system_process(&process_name) {
                    continue;
                }

                // Try to get a more user-friendly name
                let display_name = self.get_display_name(&process_name, *pid);
                
                // Skip duplicates (same display name)
                if seen_names.contains_key(&display_name) {
                    continue;
                }
                seen_names.insert(display_name.clone(), true);

                let bundle_id = self.get_bundle_id(*pid);
                let path = process.exe().map(|p| p.to_string_lossy().to_string());
                
                apps.push(ApplicationData {
                    name: display_name,
                    bundle_id,
                    path,
                    pid: pid.as_u32() as i32,
                    is_active: self.is_process_active(*pid),
                });
            }

            Ok(apps)
        }
    }

    fn find_all_matches(&self, identifier: &str, apps: &[ApplicationData]) -> Vec<AppMatch> {
        let mut matches = Vec::new();
        let lower_identifier = identifier.to_lowercase();

        for app in apps {
            let lower_app_name = app.name.to_lowercase();

            // Check exact name match
            if lower_app_name == lower_identifier {
                matches.push(AppMatch {
                    app: app.clone(),
                    score: 1.0,
                    match_type: "exact_name".to_string(),
                });
                continue;
            }

            // Check prefix match
            if lower_app_name.starts_with(&lower_identifier) {
                let score = lower_identifier.len() as f64 / lower_app_name.len() as f64;
                matches.push(AppMatch {
                    app: app.clone(),
                    score,
                    match_type: "prefix".to_string(),
                });
                continue;
            }

            // Check contains match
            if lower_app_name.contains(&lower_identifier) {
                let score = (lower_identifier.len() as f64 / lower_app_name.len() as f64) * 0.8;
                matches.push(AppMatch {
                    app: app.clone(),
                    score,
                    match_type: "contains".to_string(),
                });
                continue;
            }

            // Check bundle ID match
            if let Some(bundle_id) = &app.bundle_id {
                if bundle_id.to_lowercase().contains(&lower_identifier) {
                    let score = (lower_identifier.len() as f64 / bundle_id.len() as f64) * 0.6;
                    matches.push(AppMatch {
                        app: app.clone(),
                        score,
                        match_type: "bundle_contains".to_string(),
                    });
                    continue;
                }
            }

            // Fuzzy matching
            let similarity = strsim::jaro_winkler(&lower_app_name, &lower_identifier);
            if similarity >= 0.7 {
                matches.push(AppMatch {
                    app: app.clone(),
                    score: similarity * 0.9,
                    match_type: "fuzzy".to_string(),
                });
            }
        }

        matches.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));
        matches
    }

    fn remove_duplicate_matches(&self, matches: Vec<AppMatch>) -> Vec<AppMatch> {
        let mut unique_matches = Vec::new();
        let mut seen_pids = std::collections::HashSet::new();

        for app_match in matches {
            if !seen_pids.contains(&app_match.app.pid) {
                seen_pids.insert(app_match.app.pid);
                unique_matches.push(app_match);
            }
        }

        unique_matches
    }

    fn process_match_results(
        &self,
        matches: Vec<AppMatch>,
        identifier: &str,
        _running_apps: &[ApplicationData],
    ) -> PeekabooResult<ApplicationData> {
        if matches.is_empty() {
            crate::logger::error(&format!("No applications found matching: {}", identifier));
            return Err(PeekabooError::app_not_found(identifier.to_string()));
        }

        // Check for ambiguous matches
        let top_score = matches[0].score;
        let threshold = if matches[0].match_type.contains("fuzzy") { 0.05 } else { 0.1 };
        let top_matches: Vec<_> = matches.iter()
            .filter(|m| (m.score - top_score).abs() < threshold)
            .collect();

        if top_matches.len() > 1 {
            let match_descriptions: Vec<String> = top_matches.iter()
                .map(|m| format!("{} (PID: {})", m.app.name, m.app.pid))
                .collect();
            
            let error_msg = format!(
                "Multiple applications match identifier '{}'. Please be more specific. Matches found: {}",
                identifier,
                match_descriptions.join(", ")
            );
            crate::logger::error(&error_msg);
            return Err(PeekabooError::invalid_argument(error_msg));
        }

        let best_match = &matches[0];
        crate::logger::debug(&format!(
            "Found application: {} (score: {:.2}, type: {})",
            best_match.app.name, best_match.score, best_match.match_type
        ));

        Ok(best_match.app.clone())
    }

    fn is_system_process(&self, name: &str) -> bool {
        // List of common system processes to filter out
        let system_processes = [
            "kernel", "kthreadd", "ksoftirqd", "migration", "rcu_", "watchdog",
            "systemd", "kworker", "dbus", "NetworkManager", "pulseaudio",
            "gdm", "gnome-session", "gnome-shell", "Xorg", "wayland",
        ];

        system_processes.iter().any(|&sys_proc| name.contains(sys_proc))
    }

    fn get_display_name(&self, process_name: &str, _pid: Pid) -> String {
        // Remove common suffixes and clean up the name
        let name = process_name
            .trim_end_matches(".exe")
            .trim_end_matches("-bin")
            .to_string();

        // Capitalize first letter
        if let Some(first_char) = name.chars().next() {
            first_char.to_uppercase().collect::<String>() + &name[1..]
        } else {
            name
        }
    }

    fn get_bundle_id(&self, _pid: Pid) -> Option<String> {
        // On Linux, we don't have bundle IDs like macOS
        // We could potentially read from .desktop files or other sources
        // For now, return None
        None
    }

    fn is_process_active(&self, _pid: Pid) -> bool {
        // On Linux, determining if a process is "active" (has focus) is complex
        // For now, assume all GUI processes are potentially active
        true
    }

    fn count_windows_for_app(&self, _pid: i32) -> i32 {
        // This will be implemented when we add window management
        // For now, return 1 for all processes to include them
        1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_application_finder_creation() {
        let finder = ApplicationFinder::new();
        // Just test that we can create the finder without panicking
        assert!(finder.system.processes().len() >= 0);
    }

    #[test]
    fn test_fuzzy_matching() {
        let finder = ApplicationFinder::new();
        let apps = vec![
            ApplicationData {
                name: "Firefox".to_string(),
                bundle_id: Some("org.mozilla.firefox".to_string()),
                pid: 1234,
                is_active: true,
            },
            ApplicationData {
                name: "Chrome".to_string(),
                bundle_id: Some("com.google.chrome".to_string()),
                pid: 5678,
                is_active: false,
            },
        ];

        let matches = finder.find_all_matches("fire", &apps);
        assert!(!matches.is_empty());
        assert_eq!(matches[0].app.name, "Firefox");
    }

    #[test]
    fn test_system_process_filtering() {
        let finder = ApplicationFinder::new();
        
        assert!(finder.is_system_process("systemd"));
        assert!(finder.is_system_process("kworker/0:1"));
        assert!(!finder.is_system_process("firefox"));
        assert!(!finder.is_system_process("code"));
    }
}

// Windows-specific implementations
#[cfg(windows)]
impl ApplicationFinder {
    /// Windows-specific method to get running applications with window titles
    fn get_windows_applications(&mut self) -> PeekabooResult<Vec<ApplicationData>> {
        let mut applications = Vec::new();
        let mut process_map = HashMap::new();
        
        // First, get all processes using sysinfo (cross-platform)
        self.refresh();
        for (pid, process) in self.system.processes() {
            let app_data = ApplicationData {
                name: process.name().to_string(),
                bundle_id: None, // Windows doesn't have bundle IDs like macOS
                path: process.exe().map(|p| p.to_string_lossy().to_string()),
                pid: pid.as_u32() as i32,
                is_active: false, // Will be determined by window enumeration
            };
            process_map.insert(pid.as_u32(), app_data);
        }
        
        // Then enumerate windows to find which processes have visible windows
        unsafe {
            let mut window_processes = std::collections::HashSet::new();
            
            EnumWindows(Some(enum_windows_proc), &mut window_processes as *mut _ as isize);
            
            // Mark processes with visible windows as active
            for (pid, mut app_data) in process_map {
                if window_processes.contains(&pid) {
                    app_data.is_active = true;
                }
                
                // Filter out system processes
                if !self.is_system_process(&app_data.name) {
                    applications.push(app_data);
                }
            }
        }
        
        Ok(applications)
    }
}

#[cfg(windows)]
unsafe extern "system" fn enum_windows_proc(
    hwnd: winapi::shared::windef::HWND,
    lparam: isize,
) -> i32 {
    let window_processes = &mut *(lparam as *mut std::collections::HashSet<u32>);
    
    // Check if window is visible
    if IsWindowVisible(hwnd) != 0 {
        let mut process_id: u32 = 0;
        GetWindowThreadProcessId(hwnd, &mut process_id);
        
        if process_id != 0 {
            // Get window title to filter out empty/system windows
            let mut title: [u16; 256] = [0; 256];
            let title_len = GetWindowTextW(hwnd, title.as_mut_ptr(), title.len() as i32);
            
            if title_len > 0 {
                window_processes.insert(process_id);
            }
        }
    }
    
    1 // Continue enumeration
}
