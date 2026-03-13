import Testing
@testable import PeekabooUICore

@Suite(.tags(.permissions))
@MainActor
struct InspectorPermissionTests {
    @Test
    func `Permission providers update status without prompt`() {
        var view = InspectorView()
        InspectorView.setPermissionProvidersForTesting(check: { true }, prompt: { false })
        defer { InspectorView.resetPermissionProvidersForTesting() }

        view.test_checkPermissions(prompt: false)
        #expect(view.test_permissionStatus() == .granted)

        InspectorView.setPermissionProvidersForTesting(check: { false }, prompt: { false })
        view.test_checkPermissions(prompt: false)
        #expect(view.test_permissionStatus() == .denied)
    }

    @Test
    func `Prompt uses prompt provider`() {
        var view = InspectorView()
        InspectorView.setPermissionProvidersForTesting(check: { false }, prompt: { true })
        defer { InspectorView.resetPermissionProvidersForTesting() }

        view.test_checkPermissions(prompt: true)
        #expect(view.test_permissionStatus() == .granted)
    }
}
