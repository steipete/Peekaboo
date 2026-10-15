import CoreGraphics
import Testing
@testable import PeekabooCLI

struct ClickCoordinateParsingTests {
    @Test
    func `finite coordinates parse`() {
        #expect(ClickCommand.parseCoordinates("100,200") == CGPoint(x: 100, y: 200))
        #expect(ClickCommand.parseCoordinates(" -5.5 , 20 ") == CGPoint(x: -5.5, y: 20))
    }

    @Test
    func `non-finite coordinates are rejected`() {
        // Double() accepts these spellings, but none of them is a screen position.
        for raw in ["nan,200", "100,nan", "inf,200", "100,-inf", "infinity,infinity"] {
            #expect(ClickCommand.parseCoordinates(raw) == nil, "\(raw) should be rejected")
        }
    }

    @Test
    func `malformed coordinates are rejected`() {
        for raw in ["", "100", "100,", ",200", "abc,def", "1,2,3"] {
            #expect(ClickCommand.parseCoordinates(raw) == nil, "\(raw) should be rejected")
        }
    }
}
