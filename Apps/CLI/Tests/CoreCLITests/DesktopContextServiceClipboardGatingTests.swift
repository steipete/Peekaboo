import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooCore
import Testing
import UniformTypeIdentifiers

@Suite("DesktopContextService clipboard gating")
struct DesktopContextServiceClipboardGatingTests {
    @Test("Does not read clipboard when clipboard tool disabled")
    @MainActor
    func doesNotReadClipboardWhenDisabled() async {
        let clipboard = RecordingClipboardService(textPreview: "should-not-be-read")
        let services = ServicesWithStubClipboard(clipboard: clipboard)
        let service = DesktopContextService(services: services)

        let context = await service.gatherContext(includeClipboardPreview: false)

        #expect(clipboard.getCallCount == 0)
        #expect(context.clipboardPreview == nil)
    }

    @Test("Reads clipboard when clipboard tool enabled")
    @MainActor
    func readsClipboardWhenEnabled() async {
        let clipboard = RecordingClipboardService(textPreview: "hello from clipboard")
        let services = ServicesWithStubClipboard(clipboard: clipboard)
        let service = DesktopContextService(services: services)

        let context = await service.gatherContext(includeClipboardPreview: true)

        #expect(clipboard.getCallCount == 1)
        #expect(context.clipboardPreview == "hello from clipboard")
    }
}

@MainActor
private final class ServicesWithStubClipboard: PeekabooServiceProviding {
    private let base = PeekabooServices()
    private let stubClipboard: any ClipboardServiceProtocol

    init(clipboard: any ClipboardServiceProtocol) {
        self.stubClipboard = clipboard
    }

    func ensureVisualizerConnection() {
        self.base.ensureVisualizerConnection()
    }

    var logging: any LoggingServiceProtocol { self.base.logging }
    var screenCapture: any ScreenCaptureServiceProtocol { self.base.screenCapture }
    var applications: any ApplicationServiceProtocol { self.base.applications }
    var automation: any UIAutomationServiceProtocol { self.base.automation }
    var windows: any WindowManagementServiceProtocol { self.base.windows }
    var menu: any MenuServiceProtocol { self.base.menu }
    var dock: any DockServiceProtocol { self.base.dock }
    var dialogs: any DialogServiceProtocol { self.base.dialogs }
    var sessions: any SessionManagerProtocol { self.base.sessions }
    var files: any FileServiceProtocol { self.base.files }
    var clipboard: any ClipboardServiceProtocol { self.stubClipboard }
    var configuration: PeekabooCore.ConfigurationManager { self.base.configuration }
    var process: any ProcessServiceProtocol { self.base.process }
    var permissions: PermissionsService { self.base.permissions }
    var audioInput: AudioInputService { self.base.audioInput }
    var screens: any ScreenServiceProtocol { self.base.screens }
    var agent: (any AgentServiceProtocol)? { self.base.agent }
}

@MainActor
private final class RecordingClipboardService: ClipboardServiceProtocol {
    private(set) var getCallCount = 0
    private let textPreview: String

    init(textPreview: String) {
        self.textPreview = textPreview
    }

    func get(prefer uti: UTType?) throws -> ClipboardReadResult? {
        self.getCallCount += 1
        return ClipboardReadResult(
            utiIdentifier: UTType.plainText.identifier,
            data: Data(self.textPreview.utf8),
            textPreview: self.textPreview)
    }

    func set(_ request: ClipboardWriteRequest) throws -> ClipboardReadResult {
        throw ClipboardServiceError.writeFailed("Not implemented in test stub.")
    }

    func clear() {}

    func save(slot: String) throws {
        throw ClipboardServiceError.writeFailed("Not implemented in test stub.")
    }

    func restore(slot: String) throws -> ClipboardReadResult {
        throw ClipboardServiceError.writeFailed("Not implemented in test stub.")
    }
}

