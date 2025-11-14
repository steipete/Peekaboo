import SwiftUI

struct PermissionBubbleView: View {
    @EnvironmentObject var actionLogger: ActionLogger

    var body: some View {
        GroupBox("Permission Bubble Simulation") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Simulates a browser permission bubble with unlabeled buttons.")
                    .font(.callout)

                Text("example.com wants to use your location.")
                    .font(.headline)

                HStack(spacing: 16) {
                    self.permissionButton(title: "Don't Allow", identifier: "permission-deny-button")
                    self.permissionButton(title: "Allow", identifier: "permission-allow-button")
                }
            }
        }
        .padding(.vertical)
    }

    private func permissionButton(title: String, identifier: String) -> some View {
        Button(
            action: {
                self.actionLogger.log(.click, "Tapped permission action", details: title)
            },
            label: {
                Text(title)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(8)
            })
            .accessibilityLabel("button")
            .accessibilityIdentifier(identifier)
            .buttonStyle(.plain)
    }
}
