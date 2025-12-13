import SwiftUI

struct PermissionsSettingsView: View {
    @Environment(Permissions.self) private var permissions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Grant required permissions so Peekaboo can capture and automate reliably.")
                .padding(.top, 4)

            PermissionChecklistView(showOptional: true)
                .padding(.horizontal, 2)
                .padding(.vertical, 6)

            Button("Show permissions onboarding") {
                PermissionsOnboardingController.shared.show(permissions: self.permissions)
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

#if DEBUG
struct PermissionsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsSettingsView()
            .environment(Permissions())
            .frame(width: 550, height: 700)
    }
}
#endif
