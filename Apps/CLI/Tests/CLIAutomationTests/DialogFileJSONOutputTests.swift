import Foundation
import PeekabooCore
import Testing

@testable import PeekabooCLI

@Suite("dialog file JSON output", .serialized, .tags(.unit))
struct DialogFileJSONOutputTests {
    @Test("dialog file forwards path_navigation_method in JSON")
    func dialogFileIncludesPathNavigationMethod() async throws {
        let elements = DialogElements(
            dialogInfo: DialogInfo(
                title: "Save",
                role: "AXWindow",
                subrole: "AXDialog",
                isFileDialog: true,
                bounds: .init(x: 0, y: 0, width: 420, height: 320)
            ),
            buttons: [],
            textFields: [],
            staticTexts: []
        )

        let dialogService = StubDialogService(elements: elements)
        dialogService.handleFileDialogResult = DialogActionResult(
            success: true,
            action: .handleFileDialog,
            details: [
                "dialog_identifier": "sheet:Save:0",
                "found_via": "ax",
                "path": "/tmp",
                "path_navigation_method": "path_textfield_typed+fallback_go_to_folder",
                "filename": "out.txt",
                "button_clicked": "Save",
                "button_identifier": "OKButton",
                "saved_path": "/tmp/out.txt",
                "saved_path_verified": "true",
                "saved_path_found_via": "expected_path",
            ]
        )

        let services = TestServicesFactory.makePeekabooServices(dialogs: dialogService)
        let result = try await InProcessCommandRunner.run(
            ["dialog", "file", "--path", "/tmp", "--name", "out.txt", "--select", "Save", "--json"],
            services: services
        )

        struct Payload: Codable {
            let action: String
            let dialogIdentifier: String?
            let foundVia: String?
            let path: String?
            let pathNavigationMethod: String?
            let name: String?
            let buttonClicked: String

            enum CodingKeys: String, CodingKey {
                case action
                case dialogIdentifier = "dialog_identifier"
                case foundVia = "found_via"
                case path
                case pathNavigationMethod = "path_navigation_method"
                case name
                case buttonClicked
            }
        }

        let output = result.stdout.isEmpty ? result.stderr : result.stdout
        let response = try JSONDecoder().decode(CodableJSONResponse<Payload>.self, from: Data(output.utf8))
        #expect(response.success == true)
        #expect(response.data.action == "file_dialog")
        #expect(response.data.dialogIdentifier == "sheet:Save:0")
        #expect(response.data.foundVia == "ax")
        #expect(response.data.path == "/tmp")
        #expect(response.data.name == "out.txt")
        #expect(response.data.buttonClicked == "Save")
        #expect(response.data.pathNavigationMethod == "path_textfield_typed+fallback_go_to_folder")
    }
}
