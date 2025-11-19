import Testing
@testable import PeekabooUICore

@Suite("Inspector Permission Tests", .tags(.permissions))
@MainActor
struct InspectorPermissionTests {
    @Test("Permission providers update status without prompt")
    func permissionStatusUpdates() {
        var view = InspectorView()
        InspectorView.setPermissionProvidersForTesting(check: { true }, prompt: { false })
        defer { InspectorView.resetPermissionProvidersForTesting() }

        view.test_checkPermissions(prompt: false)
        #expect(view.test_permissionStatus() == .granted)

        InspectorView.setPermissionProvidersForTesting(check: { false }, prompt: { false })
        view.test_checkPermissions(prompt: false)
        #expect(view.test_permissionStatus() == .denied)
    }

    @Test("Prompt uses prompt provider")
    func promptUsesProvider() {
        var view = InspectorView()
        InspectorView.setPermissionProvidersForTesting(check: { false }, prompt: { true })
        defer { InspectorView.resetPermissionProvidersForTesting() }

        view.test_checkPermissions(prompt: true)
        #expect(view.test_permissionStatus() == .granted)
    }
}
