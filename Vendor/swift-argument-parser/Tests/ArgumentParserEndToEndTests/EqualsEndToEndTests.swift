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

final class EqualsEndToEndTests: XCTestCase {}

// MARK: .short name

private struct Foo: ParsableArguments {
  @Flag(name: .short) var toggle: Bool = false
  @Option(name: .short) var name: String?
  @Option(name: .short) var format: String
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension EqualsEndToEndTests {
  func testEquals_withShortName() throws {
    AssertParse(Foo.self, ["-n=Name", "-f=Format"]) { foo in
      XCTAssertEqual(foo.toggle, false)
      XCTAssertEqual(foo.name, "Name")
      XCTAssertEqual(foo.format, "Format")
    }
  }

  func testEquals_withCombinedShortName_1() throws {
    AssertParse(Foo.self, ["-tf", "Format"]) { foo in
      XCTAssertEqual(foo.toggle, true)
      XCTAssertEqual(foo.name, nil)
      XCTAssertEqual(foo.format, "Format")
    }
  }

  func testEquals_withCombinedShortName_2() throws {
    XCTAssertThrowsError(try Foo.parse(["-tf=Format"]))
  }
}

// MARK: .shortAndLong name

private struct Bar: ParsableArguments {
  @Option(name: .shortAndLong) var name: String
  @Option(name: .shortAndLong) var format: String
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension EqualsEndToEndTests {
  func testEquals_withShortAndLongName() throws {
    AssertParse(Bar.self, ["-n=Name", "-f=Format"]) { bar in
      XCTAssertEqual(bar.name, "Name")
      XCTAssertEqual(bar.format, "Format")
    }
  }
}

// MARK: .customShort name

private struct Baz: ParsableArguments {
  @Option(name: .customShort("i")) var name: String
  @Option(name: .customShort("t")) var format: String
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension EqualsEndToEndTests {
  func testEquals_withCustomShortName() throws {
    AssertParse(Baz.self, ["-i=Name", "-t=Format"]) { baz in
      XCTAssertEqual(baz.name, "Name")
      XCTAssertEqual(baz.format, "Format")
    }
  }
}
