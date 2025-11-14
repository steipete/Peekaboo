import SwiftUI

struct HiddenFieldsView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var firstField = ""
    @State private var secondField = ""

    var body: some View {
        GroupBox("Hidden Web-style Text Fields") {
            VStack(alignment: .leading, spacing: 16) {
                Text("These text fields mimic web views that wrap inputs inside AXGroup containers.").font(.callout)

                HiddenProxyField(
                    label: "Email",
                    text: self.$firstField,
                    placeholder: "name@example.com",
                    identifier: "hidden-email-field",
                    logger: self.actionLogger)

                HiddenProxyField(
                    label: "Password",
                    text: self.$secondField,
                    placeholder: "••••••••",
                    identifier: "hidden-password-field",
                    logger: self.actionLogger,
                    secure: true)
            }
        }
        .padding(.vertical)
    }
}

private struct HiddenProxyField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let identifier: String
    let logger: ActionLogger
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(self.label).font(.subheadline).bold()

            HStack {
                self.renderedField
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .accessibilityIdentifier("group-\(self.identifier)")
            .accessibilityAddTraits(.isStaticText)
        }
    }

    @ViewBuilder
    private var renderedField: some View {
        if self.secure {
            SecureField(self.placeholder, text: self.$text)
                .accessibilityIdentifier(self.identifier)
                .onSubmit { self.logger.log(.text, "Hidden secure field submitted") }
        } else {
            TextField(self.placeholder, text: self.$text)
                .accessibilityIdentifier(self.identifier)
                .onSubmit { self.logger.log(.text, "Hidden text field submitted") }
        }
    }
}
