use std::process::Command;
use std::path::Path;

#[test]
fn test_binary_exists() {
    let binary_path = "target/debug/peekaboo";
    assert!(Path::new(binary_path).exists(), "Binary should exist after build");
}

#[test]
fn test_help_command() {
    let output = Command::new("target/debug/peekaboo")
        .arg("--help")
        .output()
        .expect("Failed to execute command");
    
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("A cross-platform utility for screen capture"));
    assert!(stdout.contains("image"));
    assert!(stdout.contains("list"));
}

#[test]
fn test_version_command() {
    let output = Command::new("target/debug/peekaboo")
        .arg("--version")
        .output()
        .expect("Failed to execute command");
    
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("peekaboo"));
}

#[test]
fn test_list_help() {
    let output = Command::new("target/debug/peekaboo")
        .args(&["list", "--help"])
        .output()
        .expect("Failed to execute command");
    
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("List running applications or windows"));
    assert!(stdout.contains("apps"));
    assert!(stdout.contains("windows"));
    assert!(stdout.contains("server-status"));
}

#[test]
fn test_image_help() {
    let output = Command::new("target/debug/peekaboo")
        .args(&["image", "--help"])
        .output()
        .expect("Failed to execute command");
    
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Capture screen or window images"));
    assert!(stdout.contains("--app"));
    assert!(stdout.contains("--path"));
    assert!(stdout.contains("--mode"));
    assert!(stdout.contains("--format"));
}

#[test]
fn test_invalid_command() {
    let output = Command::new("target/debug/peekaboo")
        .arg("invalid-command")
        .output()
        .expect("Failed to execute command");
    
    assert!(!output.status.success());
}

#[test]
fn test_list_apps_help() {
    let output = Command::new("target/debug/peekaboo")
        .args(&["list", "apps", "--help"])
        .output()
        .expect("Failed to execute command");
    
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("List all running applications"));
}

#[test]
fn test_list_windows_help() {
    let output = Command::new("target/debug/peekaboo")
        .args(&["list", "windows", "--help"])
        .output()
        .expect("Failed to execute command");
    
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("List windows for a specific application"));
}

#[test]
fn test_list_server_status_help() {
    let output = Command::new("target/debug/peekaboo")
        .args(&["list", "server-status", "--help"])
        .output()
        .expect("Failed to execute command");
    
    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Check server permissions status"));
}

// Note: These tests will fail in headless environments but are useful for local testing
#[test]
#[ignore] // Ignore by default since it requires a display
fn test_list_apps_json() {
    let output = Command::new("target/debug/peekaboo")
        .args(&["list", "apps", "--json-output"])
        .output()
        .expect("Failed to execute command");
    
    if output.status.success() {
        let stdout = String::from_utf8(output.stdout).unwrap();
        // Should be valid JSON
        let _: serde_json::Value = serde_json::from_str(&stdout)
            .expect("Output should be valid JSON");
    }
}

#[test]
#[ignore] // Ignore by default since it requires a display
fn test_server_status_json() {
    let output = Command::new("target/debug/peekaboo")
        .args(&["list", "server-status", "--json-output"])
        .output()
        .expect("Failed to execute command");
    
    if output.status.success() {
        let stdout = String::from_utf8(output.stdout).unwrap();
        // Should be valid JSON
        let _: serde_json::Value = serde_json::from_str(&stdout)
            .expect("Output should be valid JSON");
    }
}

