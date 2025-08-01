import Foundation
import Observation

// MARK: - Observable Service Protocol

/// Base protocol for observable services that provide state management
@available(macOS 14.0, *)
public protocol ObservableService: AnyObject {
    associatedtype State: Sendable

    /// The current state of the service
    var state: State { get }

    /// Start monitoring for state changes
    func startMonitoring() async

    /// Stop monitoring for state changes
    func stopMonitoring() async

    /// Check if monitoring is active
    var isMonitoring: Bool { get }
}

// MARK: - Observable Service State

/// Protocol for service state objects
public protocol ServiceState: Sendable {
    /// Whether the service is currently loading
    var isLoading: Bool { get }

    /// Last error encountered by the service
    var lastError: Error? { get }

    /// Timestamp of last update
    var lastUpdated: Date { get }
}

// MARK: - Refreshable Service

/// Protocol for services that support manual refresh
@available(macOS 14.0, *)
public protocol RefreshableService: ObservableService {
    /// Manually refresh the service state
    func refresh() async throws

    /// Check if refresh is available
    var canRefresh: Bool { get }

    /// Check if currently refreshing
    var isRefreshing: Bool { get }
}

// MARK: - Configurable Service

/// Protocol for services that support configuration
@available(macOS 14.0, *)
public protocol ConfigurableService: ObservableService {
    associatedtype Configuration

    /// Current configuration
    var configuration: Configuration { get }

    /// Update the service configuration
    func updateConfiguration(_ configuration: Configuration) async throws

    /// Validate a configuration before applying
    func validateConfiguration(_ configuration: Configuration) -> Result<Void, Error>
}

// MARK: - Service Lifecycle

/// Protocol for services with lifecycle management
@available(macOS 14.0, *)
public protocol ServiceLifecycle: AnyObject {
    /// Initialize the service
    func initialize() async throws

    /// Start the service
    func start() async throws

    /// Stop the service
    func stop() async throws

    /// Cleanup service resources
    func cleanup() async

    /// Current lifecycle state
    var lifecycleState: ServiceLifecycleState { get }
}

/// Service lifecycle states
public enum ServiceLifecycleState: String, Sendable {
    case uninitialized
    case initializing
    case initialized
    case starting
    case running
    case stopping
    case stopped
    case failed
}

// MARK: - Service Registry Protocol

/// Protocol for service registries
@available(macOS 14.0, *)
public protocol ServiceRegistry {
    /// Register a service
    func register<T>(_ service: T, for type: T.Type)

    /// Retrieve a service
    func get<T>(_ type: T.Type) -> T?

    /// Remove a service
    func remove(_ type: (some Any).Type)

    /// Check if a service is registered
    func contains(_ type: (some Any).Type) -> Bool

    /// Get all registered service types
    var registeredTypes: [String] { get }
}

// MARK: - Service Event

/// Events emitted by observable services
public enum ServiceEvent: Sendable {
    case stateChanged
    case errorOccurred(Error)
    case refreshStarted
    case refreshCompleted
    case configurationChanged
    case lifecycleChanged(ServiceLifecycleState)
}

// MARK: - Service Observer

/// Protocol for observing service events
@available(macOS 14.0, *)
public protocol ServiceObserver: AnyObject {
    /// Handle a service event
    func handleServiceEvent(_ event: ServiceEvent)
}

// MARK: - Default Implementations

extension ServiceState {
    public var isLoading: Bool { false }
    public var lastError: Error? { nil }
    public var lastUpdated: Date { Date() }
}

@available(macOS 14.0, *)
extension RefreshableService {
    public var canRefresh: Bool { !isRefreshing }
}
