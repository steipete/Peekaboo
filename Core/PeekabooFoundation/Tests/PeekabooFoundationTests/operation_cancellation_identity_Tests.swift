import Foundation
import PeekabooFoundation
import Testing

struct OperationCancellationIdentityTests {
    @Test
    func `thrown cancellation keeps its type`() async {
        do {
            let _: Int = try await performOperation({ throw CancellationError() }, errorContext: "fixture")
            Issue.record("Cancellation was lost")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test
    func `successful operation still returns its value`() async throws {
        let value = try await performOperation({ 42 }, errorContext: "fixture")
        #expect(value == 42)
    }

    @Test
    func `ordinary failures keep their context`() async {
        do {
            let _: Int = try await performOperation(
                { throw NSError(domain: "fixture", code: 1) },
                errorContext: "retained context")
            Issue.record("Expected failure")
        } catch {
            #expect(error is PeekabooError)
            #expect(error.localizedDescription.contains("retained context"))
        }
    }
}
