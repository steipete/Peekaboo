//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import ArgumentParserTestHelpers
import XCTest

final class PositionalEndToEndTests: XCTestCase {
}

// MARK: Single value String

private struct Bar: ParsableArguments {
  @Argument() var name: String
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension PositionalEndToEndTests {
  func testParsing_SinglePositional() throws {
    AssertParse(Bar.self, ["Bar"]) { bar in
      XCTAssertEqual(bar.name, "Bar")
    }
    AssertParse(Bar.self, ["Bar-"]) { bar in
      XCTAssertEqual(bar.name, "Bar-")
    }
    AssertParse(Bar.self, ["Bar--"]) { bar in
      XCTAssertEqual(bar.name, "Bar--")
    }
    AssertParse(Bar.self, ["--", "-Bar"]) { bar in
      XCTAssertEqual(bar.name, "-Bar")
    }
    AssertParse(Bar.self, ["--", "--Bar"]) { bar in
      XCTAssertEqual(bar.name, "--Bar")
    }
    AssertParse(Bar.self, ["--", "--"]) { bar in
      XCTAssertEqual(bar.name, "--")
    }
  }

  func testParsing_SinglePositional_Fails() throws {
    XCTAssertThrowsError(try Bar.parse([]))
    XCTAssertThrowsError(try Bar.parse(["--name"]))
    XCTAssertThrowsError(try Bar.parse(["Foo", "Bar"]))
  }
}

// MARK: Two values

private struct Baz: ParsableArguments {
  @Argument() var name: String
  @Argument() var format: String
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension PositionalEndToEndTests {
  func testParsing_TwoPositional() throws {
    AssertParse(Baz.self, ["Bar", "Foo"]) { baz in
      XCTAssertEqual(baz.name, "Bar")
      XCTAssertEqual(baz.format, "Foo")
    }
    AssertParse(Baz.self, ["", "Foo"]) { baz in
      XCTAssertEqual(baz.name, "")
      XCTAssertEqual(baz.format, "Foo")
    }
    AssertParse(Baz.self, ["Bar", ""]) { baz in
      XCTAssertEqual(baz.name, "Bar")
      XCTAssertEqual(baz.format, "")
    }
    AssertParse(Baz.self, ["--", "--b", "--f"]) { baz in
      XCTAssertEqual(baz.name, "--b")
      XCTAssertEqual(baz.format, "--f")
    }
    AssertParse(Baz.self, ["b", "--", "--f"]) { baz in
      XCTAssertEqual(baz.name, "b")
      XCTAssertEqual(baz.format, "--f")
    }
  }

  func testParsing_TwoPositional_Fails() throws {
    XCTAssertThrowsError(try Baz.parse(["Bar", "Foo", "Baz"]))
    XCTAssertThrowsError(try Baz.parse(["Bar"]))
    XCTAssertThrowsError(try Baz.parse([]))
    XCTAssertThrowsError(try Baz.parse(["--name", "Bar", "Foo"]))
    XCTAssertThrowsError(try Baz.parse(["Bar", "--name", "Foo"]))
    XCTAssertThrowsError(try Baz.parse(["Bar", "Foo", "--name"]))
  }
}

// MARK: Multiple values

private struct Qux: ParsableArguments {
  @Argument() var names: [String] = []
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension PositionalEndToEndTests {
  func testParsing_MultiplePositional() throws {
    AssertParse(Qux.self, []) { qux in
      XCTAssertEqual(qux.names, [])
    }
    AssertParse(Qux.self, ["Bar"]) { qux in
      XCTAssertEqual(qux.names, ["Bar"])
    }
    AssertParse(Qux.self, ["Bar", "Foo"]) { qux in
      XCTAssertEqual(qux.names, ["Bar", "Foo"])
    }
    AssertParse(Qux.self, ["Bar", "Foo", "Baz"]) { qux in
      XCTAssertEqual(qux.names, ["Bar", "Foo", "Baz"])
    }

    AssertParse(Qux.self, ["--", "--b", "--f"]) { qux in
      XCTAssertEqual(qux.names, ["--b", "--f"])
    }
    AssertParse(Qux.self, ["b", "--", "--f"]) { qux in
      XCTAssertEqual(qux.names, ["b", "--f"])
    }
  }

  func testParsing_MultiplePositional_Fails() throws {
    // TODO: Allow zero-argument arrays?
    XCTAssertThrowsError(try Qux.parse(["--name", "Bar", "Foo"]))
    XCTAssertThrowsError(try Qux.parse(["Bar", "--name", "Foo"]))
    XCTAssertThrowsError(try Qux.parse(["Bar", "Foo", "--name"]))
  }
}

// MARK: Single value plus multiple values

private struct Wobble: ParsableArguments {
  @Argument() var count: Int
  @Argument() var names: [String] = []
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension PositionalEndToEndTests {
  func testParsing_SingleAndMultiplePositional() throws {
    AssertParse(Wobble.self, ["5"]) { wobble in
      XCTAssertEqual(wobble.count, 5)
      XCTAssertEqual(wobble.names, [])
    }
    AssertParse(Wobble.self, ["5", "Bar"]) { wobble in
      XCTAssertEqual(wobble.count, 5)
      XCTAssertEqual(wobble.names, ["Bar"])
    }
    AssertParse(Wobble.self, ["5", "Bar", "Foo"]) { wobble in
      XCTAssertEqual(wobble.count, 5)
      XCTAssertEqual(wobble.names, ["Bar", "Foo"])
    }
    AssertParse(Wobble.self, ["5", "Bar", "Foo", "Baz"]) { wobble in
      XCTAssertEqual(wobble.count, 5)
      XCTAssertEqual(wobble.names, ["Bar", "Foo", "Baz"])
    }

    AssertParse(Wobble.self, ["5", "--", "--b", "--f"]) { wobble in
      XCTAssertEqual(wobble.count, 5)
      XCTAssertEqual(wobble.names, ["--b", "--f"])
    }
    AssertParse(Wobble.self, ["--", "5", "--b", "--f"]) { wobble in
      XCTAssertEqual(wobble.count, 5)
      XCTAssertEqual(wobble.names, ["--b", "--f"])
    }
    AssertParse(Wobble.self, ["5", "b", "--", "--f"]) { wobble in
      XCTAssertEqual(wobble.count, 5)
      XCTAssertEqual(wobble.names, ["b", "--f"])
    }
  }

  func testParsing_SingleAndMultiplePositional_Fails() throws {
    XCTAssertThrowsError(try Wobble.parse([]))
    XCTAssertThrowsError(try Wobble.parse(["--name", "Bar", "Foo"]))
    XCTAssertThrowsError(try Wobble.parse(["Bar", "--name", "Foo"]))
    XCTAssertThrowsError(try Wobble.parse(["Bar", "Foo", "--name"]))
  }
}

// MARK: Multiple parsed values

private struct Flob: ParsableArguments {
  @Argument() var counts: [Int] = []
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension PositionalEndToEndTests {
  func testParsing_MultipleParsedPositional() throws {
    AssertParse(Flob.self, []) { flob in
      XCTAssertEqual(flob.counts, [])
    }
    AssertParse(Flob.self, ["5"]) { flob in
      XCTAssertEqual(flob.counts, [5])
    }
    AssertParse(Flob.self, ["5", "6"]) { flob in
      XCTAssertEqual(flob.counts, [5, 6])
    }

    AssertParse(Flob.self, ["5", "--", "6"]) { flob in
      XCTAssertEqual(flob.counts, [5, 6])
    }
    AssertParse(Flob.self, ["--", "5", "6"]) { flob in
      XCTAssertEqual(flob.counts, [5, 6])
    }
    AssertParse(Flob.self, ["5", "6", "--"]) { flob in
      XCTAssertEqual(flob.counts, [5, 6])
    }
  }

  func testParsing_MultipleParsedPositional_Fails() throws {
    XCTAssertThrowsError(try Flob.parse(["a"]))
    XCTAssertThrowsError(try Flob.parse(["5", "6", "a"]))
  }
}

// MARK: Multiple parsed values

private struct BadlyFormed: ParsableArguments {
  @Argument() var numbers: [Int] = []
  @Argument() var name: String
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension PositionalEndToEndTests {
  // This test results in a fatal error when run, so it can't be enabled
  // or CI will prevent integration. Delete `disabled_` to verify the trap
  // locally.
  func disabled_testParsing_BadlyFormedPositional() throws {
    AssertParse(BadlyFormed.self, []) { _ in
      XCTFail("This should never execute")
    }
  }
}

// MARK: Conditional ExpressibleByArgument conformance

// Note: This retroactive conformance is a compilation test
extension Range<Int>: ArgumentParser.ExpressibleByArgument {
  public init?(argument: String) {
    guard let i = argument.firstIndex(of: ":"),
      let low = Int(String(argument[..<i])),
      let high = Int(String(argument[i...].dropFirst())),
      low <= high
    else { return nil }
    self = low..<high
  }
}

extension PositionalEndToEndTests {
  struct HasRange: ParsableArguments {
    @Argument var range: Range<Int>
  }

  func testParseCustomRangeConformance() throws {
    AssertParse(HasRange.self, ["0:4"]) { args in
      XCTAssertEqual(args.range, 0..<4)
    }

    XCTAssertThrowsError(try HasRange.parse([]))
    XCTAssertThrowsError(try HasRange.parse(["1"]))
    XCTAssertThrowsError(try HasRange.parse(["1:0"]))
  }
}
