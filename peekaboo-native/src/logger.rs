use std::sync::{Arc, Mutex};
use std::collections::VecDeque;

const MAX_DEBUG_LOGS: usize = 100;

lazy_static::lazy_static! {
    static ref DEBUG_LOGS: Arc<Mutex<VecDeque<String>>> = Arc::new(Mutex::new(VecDeque::new()));
}

pub struct Logger;

impl Logger {
    pub fn new() -> Self {
        // Initialize env_logger if not already initialized
        let _ = env_logger::try_init();
        Self
    }

    pub fn debug(&self, message: &str) {
        log::debug!("{}", message);
        self.add_debug_log(format!("DEBUG: {}", message));
    }

    pub fn info(&self, message: &str) {
        log::info!("{}", message);
        self.add_debug_log(format!("INFO: {}", message));
    }

    pub fn warn(&self, message: &str) {
        log::warn!("{}", message);
        self.add_debug_log(format!("WARN: {}", message));
    }

    pub fn error(&self, message: &str) {
        log::error!("{}", message);
        self.add_debug_log(format!("ERROR: {}", message));
    }

    fn add_debug_log(&self, message: String) {
        if let Ok(mut logs) = DEBUG_LOGS.lock() {
            if logs.len() >= MAX_DEBUG_LOGS {
                logs.pop_front();
            }
            logs.push_back(message);
        }
    }

    pub fn get_debug_logs() -> Vec<String> {
        DEBUG_LOGS
            .lock()
            .map(|logs| logs.iter().cloned().collect())
            .unwrap_or_default()
    }

    // Static methods for convenience
    pub fn debug_static(message: &str) {
        log::debug!("{}", message);
        if let Ok(mut logs) = DEBUG_LOGS.lock() {
            if logs.len() >= MAX_DEBUG_LOGS {
                logs.pop_front();
            }
            logs.push_back(format!("DEBUG: {}", message));
        }
    }

    pub fn info_static(message: &str) {
        log::info!("{}", message);
        if let Ok(mut logs) = DEBUG_LOGS.lock() {
            if logs.len() >= MAX_DEBUG_LOGS {
                logs.pop_front();
            }
            logs.push_back(format!("INFO: {}", message));
        }
    }

    pub fn warn_static(message: &str) {
        log::warn!("{}", message);
        if let Ok(mut logs) = DEBUG_LOGS.lock() {
            if logs.len() >= MAX_DEBUG_LOGS {
                logs.pop_front();
            }
            logs.push_back(format!("WARN: {}", message));
        }
    }

    pub fn error_static(message: &str) {
        log::error!("{}", message);
        if let Ok(mut logs) = DEBUG_LOGS.lock() {
            if logs.len() >= MAX_DEBUG_LOGS {
                logs.pop_front();
            }
            logs.push_back(format!("ERROR: {}", message));
        }
    }
}

// Convenience functions
pub fn debug(message: &str) {
    Logger::debug_static(message);
}

pub fn info(message: &str) {
    Logger::info_static(message);
}

pub fn warn(message: &str) {
    Logger::warn_static(message);
}

pub fn error(message: &str) {
    Logger::error_static(message);
}

