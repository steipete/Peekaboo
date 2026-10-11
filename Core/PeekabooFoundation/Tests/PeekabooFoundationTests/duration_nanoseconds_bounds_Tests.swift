import Foundation
import PeekabooFoundation
import Testing

struct DurationNanosecondsBoundsTests {
    @Test
    func `invalid durations do not trap`() {
        #expect(TimeInterval(-1).nanoseconds == 0)
        #expect(TimeInterval.nan.nanoseconds == 0)
        #expect((-TimeInterval.infinity).nanoseconds == 0)
        #expect(TimeInterval.infinity.nanoseconds == UInt64.max)
        #expect(TimeInterval.greatestFiniteMagnitude.nanoseconds == UInt64.max)
    }

    @Test
    func `ordinary durations retain nanosecond precision`() {
        #expect(TimeInterval(0).nanoseconds == 0)
        #expect(TimeInterval(0.125).nanoseconds == 125_000_000)
        #expect(TimeInterval(1).nanoseconds == 1_000_000_000)
    }
}
