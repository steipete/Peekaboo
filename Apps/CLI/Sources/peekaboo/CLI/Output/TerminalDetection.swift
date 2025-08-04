import Foundation
import Darwin

/// Comprehensive terminal capability detection for progressive enhancement
struct TerminalCapabilities {
    let isInteractive: Bool
    let supportsColors: Bool
    let supportsTrueColor: Bool
    let supportsTUI: Bool
    let width: Int
    let height: Int
    let termType: String?
    let isCI: Bool
    let isPiped: Bool
    
    /// Detect optimal output mode based on terminal capabilities
    var recommendedOutputMode: OutputMode {
        // Explicit overrides handled elsewhere
        
        // Environment-based fallbacks
        if !isInteractive || isCI || isPiped {
            return .minimal
        }
        
        // Capability-based progressive enhancement
        if supportsTUI && width >= 100 && height >= 20 {
            return .tui
        }
        
        if supportsColors && width >= 80 {
            return .enhanced
        }
        
        return .compact
    }
}

/// Terminal detection utilities following modern CLI best practices
enum TerminalDetector {
    
    /// Detect comprehensive terminal capabilities
    static func detectCapabilities() -> TerminalCapabilities {
        let isInteractive = isInteractiveTerminal()
        let (width, height) = getTerminalDimensions()
        let termType = ProcessInfo.processInfo.environment["TERM"]
        let isCI = isCIEnvironment()
        let isPiped = isPipedOutput()
        
        let supportsColors = detectColorSupport(termType: termType, isInteractive: isInteractive)
        let supportsTrueColor = detectTrueColorSupport()
        let supportsTUI = detectTUISupport(
            isInteractive: isInteractive,
            supportsColors: supportsColors,
            width: width,
            height: height,
            termType: termType,
            isCI: isCI
        )
        
        return TerminalCapabilities(
            isInteractive: isInteractive,
            supportsColors: supportsColors,
            supportsTrueColor: supportsTrueColor,
            supportsTUI: supportsTUI,
            width: width,
            height: height,
            termType: termType,
            isCI: isCI,
            isPiped: isPiped
        )
    }
    
    // MARK: - Core Detection Methods
    
    /// Check if stdout is connected to an interactive terminal
    private static func isInteractiveTerminal() -> Bool {
        return isatty(STDOUT_FILENO) != 0
    }
    
    /// Check if output is being piped or redirected
    private static func isPipedOutput() -> Bool {
        return isatty(STDOUT_FILENO) == 0
    }
    
    /// Detect CI/automation environments
    private static func isCIEnvironment() -> Bool {
        let ciVariables = [
            "CI", "CONTINUOUS_INTEGRATION",
            "GITHUB_ACTIONS", "GITHUB_WORKSPACE",
            "GITLAB_CI", "GITLAB_USER_LOGIN",
            "TRAVIS", "TRAVIS_BUILD_ID",
            "CIRCLECI", "CIRCLE_BUILD_NUM",
            "JENKINS_URL", "BUILD_NUMBER",
            "BUILDKITE", "BUILDKITE_BUILD_ID",
            "AZURE_PIPELINES", "TF_BUILD",
            "BITBUCKET_COMMIT", "BITBUCKET_BUILD_NUMBER",
            "DRONE", "DRONE_BUILD_NUMBER",
            "SEMAPHORE", "SEMAPHORE_BUILD_NUMBER"
        ]
        
        let env = ProcessInfo.processInfo.environment
        return ciVariables.contains { env[$0] != nil }
    }
    
    /// Get terminal dimensions using ioctl
    private static func getTerminalDimensions() -> (width: Int, height: Int) {
        var windowSize = winsize()
        
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &windowSize) == 0 else {
            // Fallback to environment variables
            let width = Int(ProcessInfo.processInfo.environment["COLUMNS"] ?? "80") ?? 80
            let height = Int(ProcessInfo.processInfo.environment["LINES"] ?? "24") ?? 24
            return (width, height)
        }
        
        return (
            width: Int(windowSize.ws_col),
            height: Int(windowSize.ws_row)
        )
    }
    
    // MARK: - Color Support Detection
    
    /// Detect color support using multiple methods
    private static func detectColorSupport(termType: String?, isInteractive: Bool) -> Bool {
        guard isInteractive else { return false }
        
        // Method 1: Check COLORTERM environment variable (most reliable)
        if let colorTerm = ProcessInfo.processInfo.environment["COLORTERM"] {
            return !colorTerm.isEmpty
        }
        
        // Method 2: Check TERM variable patterns
        if let term = termType {
            let colorTermPatterns = [
                "color", "256color", "truecolor", "24bit",
                "xterm-256", "screen-256", "tmux-256"
            ]
            
            if colorTermPatterns.contains(where: term.contains) {
                return true
            }
            
            // Known color-capable terminals
            let colorTerminals = [
                "xterm", "screen", "tmux", "rxvt", "konsole",
                "gnome", "mate", "xfce", "terminology", "kitty",
                "alacritty", "iterm", "hyper", "vscode"
            ]
            
            if colorTerminals.contains(where: term.contains) {
                return true
            }
        }
        
        // Method 3: Platform-specific defaults
        #if os(macOS)
        // macOS Terminal.app and most modern terminals support colors
        return true
        #else
        // Conservative fallback for other platforms
        return termType != "dumb" && termType != nil
        #endif
    }
    
    /// Detect true color (24-bit) support
    private static func detectTrueColorSupport() -> Bool {
        let env = ProcessInfo.processInfo.environment
        
        // Check COLORTERM for explicit true color support
        if let colorTerm = env["COLORTERM"] {
            return colorTerm.contains("truecolor") || colorTerm.contains("24bit")
        }
        
        // Check for terminals known to support true color
        if let term = env["TERM"] {
            let trueColorTerminals = [
                "iterm", "kitty", "alacritty", "wezterm", 
                "hyper", "vscode", "gnome-terminal"
            ]
            return trueColorTerminals.contains(where: term.contains)
        }
        
        #if os(macOS)
        // Most modern macOS terminals support true color
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - TUI Support Detection
    
    /// Detect full TUI support requirements
    private static func detectTUISupport(
        isInteractive: Bool,
        supportsColors: Bool,
        width: Int,
        height: Int,
        termType: String?,
        isCI: Bool
    ) -> Bool {
        // Basic requirements
        guard isInteractive && supportsColors && !isCI else {
            return false
        }
        
        // Size requirements for usable TUI
        guard width >= 100 && height >= 20 else {
            return false
        }
        
        // Terminal type exclusions
        if let term = termType {
            let excludedTerminals = ["dumb", "unknown", "cons25"]
            if excludedTerminals.contains(term) {
                return false
            }
        }
        
        // Check for TermKit availability
        #if canImport(TermKit)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Utility Methods
    
    /// Get a human-readable description of terminal capabilities
    static func capabilitiesDescription(_ caps: TerminalCapabilities) -> String {
        var features: [String] = []
        
        if caps.isInteractive { features.append("interactive") }
        if caps.supportsColors { features.append("colors") }
        if caps.supportsTrueColor { features.append("truecolor") }
        if caps.supportsTUI { features.append("TUI-capable") }
        if caps.isCI { features.append("CI-environment") }
        if caps.isPiped { features.append("piped") }
        
        let sizeInfo = "\(caps.width)x\(caps.height)"
        let termInfo = caps.termType ?? "unknown"
        
        return "\(termInfo) (\(sizeInfo)) - \(features.joined(separator: ", "))"
    }
    
    /// Check if we should force a specific output mode based on environment
    static func shouldForceOutputMode() -> OutputMode? {
        let env = ProcessInfo.processInfo.environment
        
        // Check for explicit output mode environment variables
        if let mode = env["PEEKABOO_OUTPUT_MODE"] {
            switch mode.lowercased() {
            case "minimal", "simple": return .minimal
            case "compact": return .compact
            case "enhanced", "rich": return .enhanced
            case "tui", "full": return .tui
            default: break
            }
        }
        
        // Check for NO_COLOR standard
        if env["NO_COLOR"] != nil {
            return .minimal
        }
        
        // Check for explicit color forcing
        if env["FORCE_COLOR"] != nil || env["CLICOLOR_FORCE"] != nil {
            return .enhanced
        }
        
        return nil
    }
}

// MARK: - Output Mode Extensions

extension OutputMode {
    /// Get a human-readable description of the output mode
    var description: String {
        switch self {
        case .minimal:
            return "Minimal (no colors, CI-friendly)"
        case .compact:
            return "Compact (colors and icons)"
        case .enhanced:
            return "Enhanced (rich formatting and progress)"
        case .tui:
            return "TUI (full terminal interface)"
        case .quiet:
            return "Quiet (results only)"
        case .verbose:
            return "Verbose (debug information)"
        }
    }
    
    /// Check if this mode supports colors
    var supportsColors: Bool {
        switch self {
        case .minimal, .quiet:
            return false
        case .compact, .enhanced, .tui, .verbose:
            return true
        }
    }
    
    /// Check if this mode supports rich formatting
    var supportsRichFormatting: Bool {
        switch self {
        case .minimal, .quiet, .compact:
            return false
        case .enhanced, .tui, .verbose:
            return true
        }
    }
}