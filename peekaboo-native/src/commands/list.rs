use clap::{Parser, Subcommand};
use crate::errors::PeekabooResult;
use crate::models::{ApplicationListData, WindowListData, ServerStatusData, ServerStatus, ServerPermissions, WindowDetailOption, TargetApplicationInfo};
use crate::platform;
use crate::json_output::{self, Logger};

#[derive(Parser, Clone)]
pub struct ListCommand {
    #[command(subcommand)]
    pub subcommand: ListSubcommand,
}

#[derive(Subcommand, Clone)]
pub enum ListSubcommand {
    /// List all running applications
    Apps(AppsCommand),
    /// List windows for a specific application
    Windows(WindowsCommand),
    /// Check server permissions status
    ServerStatus(ServerStatusCommand),
}

#[derive(Parser, Clone)]
pub struct AppsCommand {
    /// Output results in JSON format
    #[arg(long)]
    pub json_output: bool,
}

#[derive(Parser, Clone)]
pub struct WindowsCommand {
    /// Target application identifier
    #[arg(long)]
    pub app: String,

    /// Include additional window details (comma-separated: off_screen,bounds,ids)
    #[arg(long)]
    pub include_details: Option<String>,

    /// Output results in JSON format
    #[arg(long)]
    pub json_output: bool,
}

#[derive(Parser, Clone)]
pub struct ServerStatusCommand {
    /// Output results in JSON format
    #[arg(long)]
    pub json_output: bool,
}

impl ListCommand {
    pub fn execute(&self) -> PeekabooResult<()> {
        match &self.subcommand {
            ListSubcommand::Apps(cmd) => cmd.execute(),
            ListSubcommand::Windows(cmd) => cmd.execute(),
            ListSubcommand::ServerStatus(cmd) => cmd.execute(),
        }
    }
    
    pub fn is_json_output(&self) -> bool {
        match &self.subcommand {
            ListSubcommand::Apps(cmd) => cmd.json_output,
            ListSubcommand::Windows(cmd) => cmd.json_output,
            ListSubcommand::ServerStatus(cmd) => cmd.json_output,
        }
    }
}

impl AppsCommand {
    pub fn execute(&self) -> PeekabooResult<()> {
        Logger::debug("Executing apps list command");
        
        let platform = platform::get_platform()?;
        
        // Check permissions
        if !platform.check_screen_recording_permission() {
            platform.request_screen_recording_permission()?;
        }
        
        let applications = platform.get_all_applications()?;
        let data = ApplicationListData { applications: applications.clone() };
        
        if self.json_output {
            json_output::output_success(data, None);
        } else {
            self.print_application_list(&applications);
        }
        
        Ok(())
    }
    
    fn print_application_list(&self, applications: &[crate::models::ApplicationInfo]) {
        println!("Running Applications ({}):\n", applications.len());
        
        for (index, app) in applications.iter().enumerate() {
            println!("{}. {}", index + 1, app.app_name);
            println!("   Bundle ID: {}", app.bundle_id);
            println!("   PID: {}", app.pid);
            println!("   Status: {}", if app.is_active { "Active" } else { "Background" });
            
            // Only show window count if it's not 1
            if app.window_count != 1 {
                println!("   Windows: {}", app.window_count);
            }
            println!();
        }
    }
}

impl WindowsCommand {
    pub fn execute(&self) -> PeekabooResult<()> {
        Logger::debug(&format!("Executing windows list command for app: {}", self.app));
        
        let platform = platform::get_platform()?;
        
        // Check permissions
        if !platform.check_screen_recording_permission() {
            platform.request_screen_recording_permission()?;
        }
        
        let app = platform.find_application(&self.app)?;
        let detail_options = self.parse_include_details();
        
        let windows = platform.get_windows_for_app(app.pid)?;
        let window_infos: Vec<_> = windows.iter()
            .map(|w| w.to_window_info(
                detail_options.contains(&WindowDetailOption::Bounds),
                detail_options.contains(&WindowDetailOption::Ids)
            ))
            .collect();
        
        let target_app_info = TargetApplicationInfo {
            app_name: app.app_name.clone(),
            bundle_id: Some(app.bundle_id.clone()),
            pid: app.pid,
        };
        
        let data = WindowListData {
            windows: window_infos.clone(),
            target_application_info: target_app_info.clone(),
        };
        
        if self.json_output {
            json_output::output_success(data, None);
        } else {
            self.print_window_list(&target_app_info, &window_infos);
        }
        
        Ok(())
    }
    
    fn parse_include_details(&self) -> Vec<WindowDetailOption> {
        let mut options = Vec::new();
        
        if let Some(details_string) = &self.include_details {
            let components: Vec<&str> = details_string.split(',')
                .map(|s| s.trim())
                .collect();
            
            for component in components {
                match component {
                    "off_screen" => options.push(WindowDetailOption::OffScreen),
                    "bounds" => options.push(WindowDetailOption::Bounds),
                    "ids" => options.push(WindowDetailOption::Ids),
                    _ => {} // Ignore unknown options
                }
            }
        }
        
        options
    }
    
    fn print_window_list(&self, app: &TargetApplicationInfo, windows: &[crate::models::WindowInfo]) {
        println!("Windows for {}", app.app_name);
        if let Some(bundle_id) = &app.bundle_id {
            println!("Bundle ID: {}", bundle_id);
        }
        println!("PID: {}", app.pid);
        println!("Total Windows: {}", windows.len());
        println!();
        
        if windows.is_empty() {
            println!("No windows found.");
            return;
        }
        
        for (index, window) in windows.iter().enumerate() {
            println!("{}. \"{}\"", index + 1, window.window_title);
            
            if let Some(window_id) = window.window_id {
                println!("   Window ID: {}", window_id);
            }
            
            if let Some(is_on_screen) = window.is_on_screen {
                println!("   On Screen: {}", if is_on_screen { "Yes" } else { "No" });
            }
            
            if let Some(bounds) = &window.bounds {
                println!("   Bounds: ({}, {}) {}×{}", 
                        bounds.x_coordinate, bounds.y_coordinate, 
                        bounds.width, bounds.height);
            }
            
            println!();
        }
    }
}

impl ServerStatusCommand {
    pub fn execute(&self) -> PeekabooResult<()> {
        Logger::debug("Executing server status command");
        
        let platform = platform::get_platform()?;
        
        let screen_recording = platform.check_screen_recording_permission();
        let accessibility = platform.check_accessibility_permission();
        
        let permissions = ServerPermissions {
            screen_recording,
            accessibility,
        };
        
        let server_status = ServerStatus {
            permissions: permissions.clone(),
            platform: platform.platform_name().to_string(),
            version: platform.platform_version(),
        };
        
        let data = ServerStatusData { server_status };
        
        if self.json_output {
            json_output::output_success(data, None);
        } else {
            self.print_server_status(&permissions);
        }
        
        Ok(())
    }
    
    fn print_server_status(&self, permissions: &ServerPermissions) {
        println!("Server Permissions Status:");
        println!("  Screen Recording: {}", 
                if permissions.screen_recording { "✅ Granted" } else { "❌ Not granted" });
        println!("  Accessibility: {}", 
                if permissions.accessibility { "✅ Granted" } else { "❌ Not granted" });
    }
}
