import AXorcist
import Foundation
import os.log
import PeekabooFoundation

/**
 * Application discovery and management service for macOS automation.
 *
 * Provides intelligent application lookup, window enumeration, and process management.
 * Supports multiple identification formats including PID, bundle ID, application name,
 * and fuzzy matching with defensive programming for app lifecycle complexities.
 *
 * ## Core Capabilities
 * - Application discovery with multiple identifier formats
 * - Window enumeration and counting via accessibility APIs
 * - Process management and focus control
 * - Fuzzy name matching with GUI app preference
 *
 * ## Identification Formats
 * - `"PID:1234"` - Direct process ID lookup
 * - `"com.apple.Safari"` - Bundle identifier matching
 * - `"Safari"` - Name matching (case-insensitive)
 * - `"Saf"` - Fuzzy matching for partial names
 *
 * ## Usage Example
 * ```swift
 * let appService = ApplicationService()
 *
 * // List all applications
 * let result = try await appService.listApplications()
 * for app in result.data.applications {
 *     print("\(app.name): \(app.windowCount) windows")
 * }
 *
 * // Find specific application
 * let safari = try await appService.findApplication(identifier: "Safari")
 * ```
 *
 * - Important: Requires Accessibility permission for window enumeration
 * - Note: Performance 5-200ms depending on operation and system load
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class ApplicationService: ApplicationServiceProtocol {
    let logger = Logger(subsystem: "boo.peekaboo.core", category: "ApplicationService")
    let windowIdentityService = WindowIdentityService()
    let permissions: PermissionsService
    let feedbackClient: any AutomationFeedbackClient

    /// Timeout for accessibility API calls to prevent hangs
    /// AX can be sluggish on some apps (e.g., Arc); allow more headroom.
    static let axTimeout: Float = 10.0

    public init(
        permissions: PermissionsService = PermissionsService(),
        feedbackClient: any AutomationFeedbackClient = NoopAutomationFeedbackClient())
    {
        // Set global AX timeout to prevent hangs
        AXTimeoutConfiguration.setGlobalTimeout(Self.axTimeout)
        self.permissions = permissions
        self.feedbackClient = feedbackClient

        // Connect to visual feedback if available.
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.feedbackClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }
}
