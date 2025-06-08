use std::path::Path;

/// Sanitize a filename by removing or replacing invalid characters
pub fn sanitize_filename(filename: &str) -> String {
    filename
        .chars()
        .map(|c| match c {
            // Replace invalid filename characters
            '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
            // Keep valid characters
            c if c.is_ascii_alphanumeric() || c == '.' || c == '-' || c == '_' || c == ' ' => c,
            // Replace other characters with underscore
            _ => '_',
        })
        .collect::<String>()
        .trim()
        .to_string()
}

/// Join path components in a cross-platform way
pub fn join_path(base: &str, filename: &str) -> String {
    let path = Path::new(base).join(filename);
    path.to_string_lossy().to_string()
}

/// Ensure a directory exists, creating it if necessary
pub fn ensure_directory_exists(path: &str) -> std::io::Result<()> {
    let path = Path::new(path);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    Ok(())
}

/// Get a unique filename by appending a number if the file already exists
pub fn get_unique_filename(path: &str) -> String {
    let path_obj = Path::new(path);
    
    if !path_obj.exists() {
        return path.to_string();
    }
    
    let stem = path_obj.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("file");
    let extension = path_obj.extension()
        .and_then(|s| s.to_str())
        .unwrap_or("");
    let parent = path_obj.parent()
        .unwrap_or_else(|| Path::new("."));
    
    for i in 1..1000 {
        let new_filename = if extension.is_empty() {
            format!("{}_{}", stem, i)
        } else {
            format!("{}_{}.{}", stem, i, extension)
        };
        
        let new_path = parent.join(new_filename);
        if !new_path.exists() {
            return new_path.to_string_lossy().to_string();
        }
    }
    
    // Fallback with timestamp if we can't find a unique name
    let timestamp = chrono::Utc::now().format("%Y%m%d_%H%M%S_%3f");
    let fallback_filename = if extension.is_empty() {
        format!("{}_{}", stem, timestamp)
    } else {
        format!("{}_{}.{}", stem, timestamp, extension)
    };
    
    parent.join(fallback_filename).to_string_lossy().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sanitize_filename() {
        assert_eq!(sanitize_filename("normal_file.txt"), "normal_file.txt");
        assert_eq!(sanitize_filename("file/with\\invalid:chars"), "file_with_invalid_chars");
        assert_eq!(sanitize_filename("file*with?special\"chars"), "file_with_special_chars");
        assert_eq!(sanitize_filename("  spaced file  "), "spaced file");
    }

    #[test]
    fn test_join_path() {
        let result = join_path("/home/user", "file.txt");
        assert!(result.contains("file.txt"));
        
        let result = join_path(".", "file.txt");
        assert_eq!(result, "./file.txt");
    }
}
