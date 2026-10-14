import Foundation
import PeekabooFoundation
import Testing

struct StandardizedCancellationCodeTests {
    @Test
    func `cancellation keeps its structured code`() {
        #expect(ErrorStandardizer.standardize(CancellationError()).code == .cancelled)
        #expect(ErrorStandardizer.standardize(NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCancelled)).code == .cancelled)
    }

    @Test
    func `ordinary and already standardized errors remain unchanged`() {
        let original = PeekabooError.fileIOError("fixture")
        #expect(ErrorStandardizer.standardize(original).code == original.code)
        #expect(ErrorStandardizer.standardize(original).userMessage == original.userMessage)
        let network = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        #expect(ErrorStandardizer.standardize(network).code != .cancelled)
    }
}
