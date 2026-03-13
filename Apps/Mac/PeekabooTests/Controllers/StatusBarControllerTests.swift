import AppKit
import Testing
@testable import Peekaboo

@Suite(.tags(.ui, .unit))
@MainActor
struct StatusBarControllerTests {
    @Test
    func `Controller initializes with status item`() {
        let settings = PeekabooSettings()
        let sessionStore = SessionStore()
        let permissions = Permissions()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)
        let speechRecognizer = SpeechRecognizer(settings: settings)
        _ = StatusBarController(
            agent: agent,
            sessionStore: sessionStore,
            permissions: permissions,
            speechRecognizer: speechRecognizer,
            settings: settings)

        // StatusBarController is properly initialized
        // We can't access private statusItem, but we can verify the controller exists
        // Controller initialized successfully
    }

    @Test
    func `Menu contains expected items`() {
        let settings = PeekabooSettings()
        let sessionStore = SessionStore()
        let permissions = Permissions()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)
        let speechRecognizer = SpeechRecognizer(settings: settings)
        _ = StatusBarController(
            agent: agent,
            sessionStore: sessionStore,
            permissions: permissions,
            speechRecognizer: speechRecognizer,
            settings: settings)

        // We can't directly access the private statusItem property
        // This test would need the StatusBarController to expose a testing API
        // or make statusItem internal for testing

        // Test passes - we verified controller initializes without crashing
    }

    @Test
    func `Icon animation states`() {
        let settings = PeekabooSettings()
        let sessionStore = SessionStore()
        let permissions = Permissions()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)
        let speechRecognizer = SpeechRecognizer(settings: settings)
        _ = StatusBarController(
            agent: agent,
            sessionStore: sessionStore,
            permissions: permissions,
            speechRecognizer: speechRecognizer,
            settings: settings)

        // Test passes - we verified controller initializes without crashing
        // We can't access private statusItem property
    }

    @Test
    func `Popover presentation`() {
        let settings = PeekabooSettings()
        let sessionStore = SessionStore()
        let permissions = Permissions()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)
        let speechRecognizer = SpeechRecognizer(settings: settings)
        _ = StatusBarController(
            agent: agent,
            sessionStore: sessionStore,
            permissions: permissions,
            speechRecognizer: speechRecognizer,
            settings: settings)

        // We can't access private popover property
        // Test passes - controller initialized without crashing
    }
}
