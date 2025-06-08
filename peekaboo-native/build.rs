fn main() {
    #[cfg(target_os = "linux")]
    {
        println!("cargo:rustc-link-lib=X11");
        println!("cargo:rustc-link-lib=Xext");
        println!("cargo:rustc-link-lib=xcb");
    }
    
    #[cfg(target_os = "windows")]
    {
        println!("cargo:rustc-link-lib=user32");
        println!("cargo:rustc-link-lib=gdi32");
        println!("cargo:rustc-link-lib=kernel32");
    }
}

