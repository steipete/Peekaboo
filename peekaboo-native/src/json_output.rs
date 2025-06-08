use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use crate::errors::PeekabooError;

// Global logger instance
static LOGGER: once_cell::sync::Lazy<Arc<Mutex<Logger>>> = 
    once_cell::sync::Lazy::new(|| Arc::new(Mutex::new(Logger::new())));

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonResponse<T> {
    pub success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub messages: Option<Vec<String>>,
    pub debug_logs: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorInfo {
    pub message: String,
    pub code: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<String>,
}

#[derive(Debug)]
pub struct Logger {
    json_mode: bool,
    debug_logs: Vec<String>,
}

impl Logger {
    pub fn new() -> Self {
        Self {
            json_mode: false,
            debug_logs: Vec::new(),
        }
    }
    
    pub fn init(json_mode: bool) {
        if let Ok(mut logger) = LOGGER.lock() {
            logger.json_mode = json_mode;
        }
    }
    
    pub fn debug(message: &str) {
        if let Ok(mut logger) = LOGGER.lock() {
            logger.debug_logs.push(message.to_string());
            if !logger.json_mode {
                log::debug!("{}", message);
            }
        }
    }
    
    pub fn info(message: &str) {
        if let Ok(logger) = LOGGER.lock() {
            if !logger.json_mode {
                log::info!("{}", message);
            }
        }
    }
    
    pub fn warn(message: &str) {
        if let Ok(logger) = LOGGER.lock() {
            if !logger.json_mode {
                log::warn!("{}", message);
            }
        }
    }
    
    pub fn error(message: &str) {
        if let Ok(logger) = LOGGER.lock() {
            if !logger.json_mode {
                log::error!("{}", message);
            }
        }
    }
    
    pub fn get_debug_logs() -> Vec<String> {
        if let Ok(logger) = LOGGER.lock() {
            logger.debug_logs.clone()
        } else {
            Vec::new()
        }
    }
    
    pub fn clear_debug_logs() {
        if let Ok(mut logger) = LOGGER.lock() {
            logger.debug_logs.clear();
        }
    }
}

pub fn output_success<T: Serialize>(data: T, messages: Option<Vec<String>>) {
    let response = JsonResponse {
        success: true,
        data: Some(data),
        messages,
        debug_logs: Logger::get_debug_logs(),
        error: None,
    };
    
    output_json(&response);
}

pub fn output_error(error: &PeekabooError) {
    let error_info = ErrorInfo {
        message: error.to_string(),
        code: error.error_code().to_string(),
        details: None,
    };
    
    let response: JsonResponse<()> = JsonResponse {
        success: false,
        data: None,
        messages: None,
        debug_logs: Logger::get_debug_logs(),
        error: Some(error_info),
    };
    
    output_json(&response);
}

fn output_json<T: Serialize>(response: &JsonResponse<T>) {
    match serde_json::to_string_pretty(response) {
        Ok(json) => println!("{}", json),
        Err(e) => {
            eprintln!("Failed to serialize JSON response: {}", e);
            // Fallback to simple error JSON
            println!(r#"{{
  "success": false,
  "error": {{
    "message": "Failed to encode JSON response",
    "code": "INTERNAL_SWIFT_ERROR"
  }},
  "debug_logs": []
}}"#);
        }
    }
}

// Add once_cell dependency
use once_cell;
