use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::sync::atomic::{AtomicBool, Ordering};
use crate::errors::PeekabooError;
use crate::logger;

static JSON_OUTPUT_MODE: AtomicBool = AtomicBool::new(false);

pub struct JsonOutputMode;

impl JsonOutputMode {
    pub fn set_global(enabled: bool) {
        JSON_OUTPUT_MODE.store(enabled, Ordering::Relaxed);
    }

    pub fn is_enabled() -> bool {
        JSON_OUTPUT_MODE.load(Ordering::Relaxed)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JsonResponse {
    pub success: bool,
    pub data: Option<Value>,
    pub messages: Option<Vec<String>>,
    pub debug_logs: Vec<String>,
    pub error: Option<ErrorInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorInfo {
    pub message: String,
    pub code: String,
    pub details: Option<String>,
}

impl JsonResponse {
    pub fn success(data: Option<Value>, messages: Option<Vec<String>>) -> Self {
        Self {
            success: true,
            data,
            messages,
            debug_logs: crate::logger::Logger::get_debug_logs(),
            error: None,
        }
    }

    pub fn error(error: &PeekabooError, details: Option<String>) -> Self {
        Self {
            success: false,
            data: None,
            messages: None,
            debug_logs: crate::logger::Logger::get_debug_logs(),
            error: Some(ErrorInfo {
                message: error.to_string(),
                code: error.error_code().to_string(),
                details,
            }),
        }
    }
}

pub fn output_json(response: &JsonResponse) {
    match serde_json::to_string_pretty(&response) {
        Ok(json) => println!("{}", json),
        Err(e) => {
            logger::error(&format!("Failed to serialize data: {}", e));
            eprintln!("Error: Failed to serialize response data");
        }
    }
}

pub fn output_success<T: Serialize>(data: &T, messages: Option<Vec<String>>) {
    let data_value = match serde_json::to_value(data) {
        Ok(value) => Some(value),
        Err(e) => {
            logger::error(&format!("Failed to serialize data: {}", e));
            None
        }
    };

    let response = JsonResponse::success(data_value, messages);
    output_json(&response);
}

pub fn output_error(error: &PeekabooError) {
    let response = JsonResponse::error(error, None);
    output_json(&response);
}

pub fn output_error_with_details(error: &PeekabooError, details: String) {
    let response = JsonResponse::error(error, Some(details));
    output_json(&response);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::ApplicationInfo;

    #[test]
    fn test_json_response_success() {
        let app_info = ApplicationInfo {
            app_name: "Test App".to_string(),
            bundle_id: "com.test.app".to_string(),
            pid: 1234,
            is_active: true,
            window_count: 2,
        };

        let data_value = serde_json::to_value(&app_info).unwrap();
        let response = JsonResponse::success(Some(data_value), None);

        assert!(response.success);
        assert!(response.data.is_some());
        assert!(response.error.is_none());
    }

    #[test]
    fn test_json_response_error() {
        let error = PeekabooError::app_not_found("TestApp".to_string());
        let response = JsonResponse::error(&error, None);

        assert!(!response.success);
        assert!(response.data.is_none());
        assert!(response.error.is_some());

        let error_info = response.error.unwrap();
        assert_eq!(error_info.code, "APP_NOT_FOUND");
        assert!(error_info.message.contains("TestApp"));
    }

    #[test]
    fn test_json_serialization() {
        let response = JsonResponse::success(None, Some(vec!["Test message".to_string()]));
        let json_result = serde_json::to_string(&response);
        assert!(json_result.is_ok());

        let json_string = json_result.unwrap();
        assert!(json_string.contains("\"success\":true"));
        assert!(json_string.contains("Test message"));
    }
}
