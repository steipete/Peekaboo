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

final class EnumEndToEndTests: XCTestCase {}

// MARK: -

private struct Bar: ParsableArguments {
  enum Index: String, Equatable, ExpressibleByArgument {
    case hello
    case goodbye
  }

  @Option()
  var index: Index
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension EnumEndToEndTests {
  func testParsing_SingleOption() throws {
    AssertParse(Bar.self, ["--index", "hello"]) { bar in
      XCTAssertEqual(bar.index, Bar.Index.hello)
    }
    AssertParse(Bar.self, ["--index", "goodbye"]) { bar in
      XCTAssertEqual(bar.index, Bar.Index.goodbye)
    }
  }

  func testParsing_SingleOptionMultipleTimes() throws {
    AssertParse(Bar.self, ["--index", "hello", "--index", "goodbye"]) { bar in
      XCTAssertEqual(bar.index, Bar.Index.goodbye)
    }
  }

  func testParsing_SingleOption_Fails() throws {
    XCTAssertThrowsError(try Bar.parse([]))
    XCTAssertThrowsError(try Bar.parse(["--index"]))
    XCTAssertThrowsError(try Bar.parse(["--index", "hell"]))
    XCTAssertThrowsError(try Bar.parse(["--index", "helloo"]))
  }
}

// MARK: -

private struct Baz: ParsableArguments {
  enum Mode: String, CaseIterable, ExpressibleByArgument {
    case generateBashScript = "generate-bash-script"
    case generateZshScript
  }

  @Option(name: .customLong("mode")) var modeOption: Mode?
  @Argument() var modeArg: Mode?
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension EnumEndToEndTests {
  func test_ParsingRawValue_Option() throws {
    AssertParse(Baz.self, ["--mode", "generate-bash-script"]) { baz in
      XCTAssertEqual(baz.modeOption, .generateBashScript)
      XCTAssertNil(baz.modeArg)
    }
    AssertParse(Baz.self, ["--mode", "generateZshScript"]) { baz in
      XCTAssertEqual(baz.modeOption, .generateZshScript)
      XCTAssertNil(baz.modeArg)
    }
  }

  func test_ParsingRawValue_Argument() throws {
    AssertParse(Baz.self, ["generate-bash-script"]) { baz in
      XCTAssertEqual(baz.modeArg, .generateBashScript)
      XCTAssertNil(baz.modeOption)
    }
    AssertParse(Baz.self, ["generateZshScript"]) { baz in
      XCTAssertEqual(baz.modeArg, .generateZshScript)
      XCTAssertNil(baz.modeOption)
    }
  }

  func test_ParsingRawValue_Fails() throws {
    XCTAssertThrowsError(try Baz.parse(["generateBashScript"]))
    XCTAssertThrowsError(try Baz.parse(["--mode generateBashScript"]))
    XCTAssertThrowsError(try Baz.parse(["generate-zsh-script"]))
    XCTAssertThrowsError(try Baz.parse(["--mode generate-zsh-script"]))
  }
}
