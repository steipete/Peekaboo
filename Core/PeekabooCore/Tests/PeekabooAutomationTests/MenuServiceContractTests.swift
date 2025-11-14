import PeekabooAutomation
import PeekabooFoundation
import Testing

@Suite("MenuService contract")
@MainActor
struct MenuServiceContractTests {
    @Test("listMenus throws appNotFound for missing app")
    func listMenusMissingApp() async throws {
        let service = MenuService()

        do {
            _ = try await service.listMenus(for: "DefinitelyNotRunningApp-ContractTest")
            Issue.record("Expected appNotFound error")
        } catch let error as PeekabooError {
            switch error {
            case .appNotFound:
                // success
                break
            default:
                Issue.record("Unexpected PeekabooError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
