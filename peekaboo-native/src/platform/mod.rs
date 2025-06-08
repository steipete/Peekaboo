use crate::traits::Platform;
use crate::errors::PeekabooResult;

#[cfg(target_os = "linux")]
pub mod linux;

#[cfg(target_os = "windows")]
pub mod windows;

#[cfg(target_os = "macos")]
pub mod macos;

/// Get the appropriate platform implementation for the current OS
pub fn get_platform() -> PeekabooResult<Box<dyn Platform>> {
    #[cfg(target_os = "linux")]
    {
        let mut platform = Box::new(linux::LinuxPlatform::new()?);
        platform.initialize()?;
        Ok(platform)
    }
    
    #[cfg(target_os = "windows")]
    {
        let mut platform = Box::new(windows::WindowsPlatform::new()?);
        platform.initialize()?;
        Ok(platform)
    }
    
    #[cfg(target_os = "macos")]
    {
        let mut platform = Box::new(macos::MacOSPlatform::new()?);
        platform.initialize()?;
        Ok(platform)
    }
    
    #[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
    {
        Err(crate::errors::PeekabooError::UnknownError(
            "Unsupported platform".to_string()
        ))
    }
}

