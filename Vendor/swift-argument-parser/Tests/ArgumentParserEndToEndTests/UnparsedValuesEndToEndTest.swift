//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import ArgumentParserTestHelpers
import XCTest

final class UnparsedValuesEndToEndTests: XCTestCase {}

// MARK: Two values + unparsed variable

private struct Qux: ParsableArguments {
  @Option() var name: String
  @Flag() var verbose = false
  var count = 0
}

private struct Quizzo: ParsableArguments {
  @Option() var name: String
  @Flag() var verbose = false
  let count: Int
  init() { self.count = 0 }  // silence warning about count not being decoded
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension UnparsedValuesEndToEndTests {
  func testParsing_TwoPlusUnparsed() throws {
    AssertParse(Qux.self, ["--name", "Qux"]) { qux in
      XCTAssertEqual(qux.name, "Qux")
      XCTAssertFalse(qux.verbose)
      XCTAssertEqual(qux.count, 0)
    }
    AssertParse(Qux.self, ["--name", "Qux", "--verbose"]) { qux in
      XCTAssertEqual(qux.name, "Qux")
      XCTAssertTrue(qux.verbose)
      XCTAssertEqual(qux.count, 0)
    }

    AssertParse(Quizzo.self, ["--name", "Qux", "--verbose"]) { quizzo in
      XCTAssertEqual(quizzo.name, "Qux")
      XCTAssertTrue(quizzo.verbose)
      XCTAssertEqual(quizzo.count, 0)
    }
  }

  func testParsing_TwoPlusUnparsed_Fails() throws {
    XCTAssertThrowsError(try Qux.parse([]))
    XCTAssertThrowsError(try Qux.parse(["--name"]))
    XCTAssertThrowsError(try Qux.parse(["--name", "Qux", "--count"]))
    XCTAssertThrowsError(try Qux.parse(["--name", "Qux", "--count", "2"]))
  }
}

// MARK: Two value + unparsed optional variable

private struct Hogeraa: ParsableArguments {
  var fullName: String? = "Full Name"
}

private struct Hogera: ParsableArguments {
  @Option() var firstName: String
  @Flag() var hasLastName = false
  var fullName: String?
  mutating func validate() throws {
    if hasLastName { fullName = "\(firstName) LastName" }
  }
}

private struct Piyo: ParsableArguments {
  @Option() var firstName: String
  @Flag() var hasLastName = false
  var fullName: String!
  mutating func validate() throws {
    fullName = firstName + (hasLastName ? " LastName" : "")
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension UnparsedValuesEndToEndTests {
  func testParsing_TwoPlusOptionalUnparsed() throws {
    AssertParse(Hogeraa.self, []) { hogeraa in
      XCTAssertEqual(hogeraa.fullName, "Full Name")
    }

    AssertParse(Hogera.self, ["--first-name", "Hogera"]) { hogera in
      XCTAssertEqual(hogera.firstName, "Hogera")
      XCTAssertFalse(hogera.hasLastName)
      XCTAssertNil(hogera.fullName)
    }
    AssertParse(Hogera.self, ["--first-name", "Hogera", "--has-last-name"]) {
      hogera in
      XCTAssertEqual(hogera.firstName, "Hogera")
      XCTAssertTrue(hogera.hasLastName)
      XCTAssertEqual(hogera.fullName, "Hogera LastName")
    }

    AssertParse(Piyo.self, ["--first-name", "Hogera"]) { piyo in
      XCTAssertEqual(piyo.firstName, "Hogera")
      XCTAssertFalse(piyo.hasLastName)
      XCTAssertEqual(piyo.fullName, "Hogera")
    }
    AssertParse(Piyo.self, ["--first-name", "Hogera", "--has-last-name"]) {
      piyo in
      XCTAssertEqual(piyo.firstName, "Hogera")
      XCTAssertTrue(piyo.hasLastName)
      XCTAssertEqual(piyo.fullName, "Hogera LastName")
    }
  }

  func testParsing_TwoPlusOptionalUnparsed_Fails() throws {
    XCTAssertThrowsError(try Hogeraa.parse(["--full-name"]))
    XCTAssertThrowsError(try Hogeraa.parse(["--full-name", "Hogera Piyo"]))
    XCTAssertThrowsError(try Hogera.parse([]))
    XCTAssertThrowsError(try Hogera.parse(["--first-name"]))
    XCTAssertThrowsError(
      try Hogera.parse(["--first-name", "Hogera", "--full-name"]))
    XCTAssertThrowsError(
      try Hogera.parse(["--first-name", "Hogera", "--full-name", "Hogera Piyo"])
    )
    XCTAssertThrowsError(try Piyo.parse([]))
    XCTAssertThrowsError(try Piyo.parse(["--first-name"]))
    XCTAssertThrowsError(
      try Piyo.parse(["--first-name", "Hogera", "--full-name"]))
    XCTAssertThrowsError(
      try Piyo.parse(["--first-name", "Hogera", "--full-name", "Hogera Piyo"]))
  }
}

// MARK: Nested unparsed decodable type

private struct Foo: ParsableCommand {
  @Flag var foo: Bool = false
  var config: Config?
  @OptionGroup var opt: OptionalArguments
  @OptionGroup var def: DefaultedArguments
}

private struct Config: Decodable {
  var name: String
  var age: Int
}

private struct OptionalArguments: ParsableArguments {
  @Argument var title: String?
  @Option var edition: Int?
}

private struct DefaultedArguments: ParsableArguments {
  @Option var one = 1
  @Option var two = 2
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension UnparsedValuesEndToEndTests {
  func testUnparsedNestedValues() {
    AssertParse(Foo.self, []) { foo in
      XCTAssertFalse(foo.foo)
      XCTAssertNil(foo.opt.title)
      XCTAssertNil(foo.opt.edition)
      XCTAssertEqual(1, foo.def.one)
      XCTAssertEqual(2, foo.def.two)
    }

    AssertParse(
      Foo.self,
      ["--foo", "--edition", "5", "Hello", "--one", "2", "--two", "1"]
    ) { foo in
      XCTAssertTrue(foo.foo)
      XCTAssertEqual("Hello", foo.opt.title)
      XCTAssertEqual(5, foo.opt.edition)
      XCTAssertEqual(2, foo.def.one)
      XCTAssertEqual(1, foo.def.two)
    }
  }

  func testUnparsedNestedValues_Fails() {
    XCTAssertThrowsError(try Foo.parse(["--edition", "aaa"]))
    XCTAssertThrowsError(try Foo.parse(["--one", "aaa"]))
  }
}

// MARK: Nested unparsed optional decodable type

private struct Barr: ParsableCommand {
  var baz: Baz? = Baz(name: "Some Name", age: 105)
}

private struct Bar: ParsableCommand {
  @Flag var bar: Bool = false
  var baz: Baz?
  var bazz: Bazz?
  mutating func validate() throws {
    if bar {
      baz = Baz(name: "Some", age: 100)
      bazz = Bazz(name: "Other", age: 101)
    }
  }
}

private struct Baz: Decodable {
  var name: String?
  var age: Int!
}

private struct Bazz: Decodable {
  var name: String?
  var age: Int
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension UnparsedValuesEndToEndTests {
  func testUnparsedNestedOptionalValue() {
    AssertParse(Barr.self, []) { barr in
      XCTAssertNotNil(barr.baz)
      XCTAssertEqual(barr.baz?.age, 105)
      XCTAssertEqual(barr.baz?.name, "Some Name")
    }

    AssertParse(Bar.self, []) { bar in
      XCTAssertFalse(bar.bar)
      XCTAssertNil(bar.baz)
      XCTAssertNil(bar.baz?.age)
      XCTAssertNil(bar.baz?.name)
      XCTAssertNil(bar.bazz)
      XCTAssertNil(bar.bazz?.age)
      XCTAssertNil(bar.bazz?.name)
    }

    AssertParse(Bar.self, ["--bar"]) { bar in
      XCTAssertTrue(bar.bar)
      XCTAssertNotNil(bar.baz)
      XCTAssertEqual(bar.baz?.name, "Some")
      XCTAssertEqual(bar.baz?.age, 100)
      XCTAssertNotNil(bar.bazz)
      XCTAssertEqual(bar.bazz?.name, "Other")
      XCTAssertEqual(bar.bazz?.age, 101)
    }
  }

  func testUnparsedNestedOptionalValue_Fails() {
    XCTAssertThrowsError(try Bar.parse(["--baz", "xyz"]))
    XCTAssertThrowsError(try Bar.parse(["--bazz", "xyz"]))
    XCTAssertThrowsError(try Bar.parse(["--name", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--age", "123"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--name", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--age", "123"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--baz"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--baz", "xyz"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--baz", "--name", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--baz", "xyz", "--name"]))
    XCTAssertThrowsError(
      try Bar.parse(["--bar", "--baz", "xyz", "--name", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--baz", "--age", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--baz", "xyz", "--age"]))
    XCTAssertThrowsError(
      try Bar.parse(["--bar", "--baz", "xyz", "--age", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--bazz"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--bazz", "xyz"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--bazz", "--name", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--bazz", "xyz", "--name"]))
    XCTAssertThrowsError(
      try Bar.parse(["--bar", "--bazz", "xyz", "--name", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--bazz", "--age", "None"]))
    XCTAssertThrowsError(try Bar.parse(["--bar", "--bazz", "xyz", "--age"]))
    XCTAssertThrowsError(
      try Bar.parse(["--bar", "--bazz", "xyz", "--age", "None"]))
  }
}

// MARK: Value + unparsed dictionary

private struct Bamf: ParsableCommand {
  @Flag var bamph: Bool = false
  var bop: [String: String] = [:]
  var bopp: [String: [String]] = [:]
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension UnparsedValuesEndToEndTests {
  func testUnparsedNestedDictionary() {
    AssertParse(Bamf.self, []) { bamf in
      XCTAssertFalse(bamf.bamph)
      XCTAssertEqual(bamf.bop, [:])
      XCTAssertEqual(bamf.bopp, [:])
    }
  }
}

// MARK: Value + unparsed enum with associated values

private struct Qiqi: ParsableCommand {
  @Flag var qiqiqi: Bool = false
  var qiqii: Qiqii = .q("")
}

private enum Qiqii: Codable, Equatable {
  // Enums with associated values generate a Codable conformance
  // which calls `KeyedDecodingContainer.nestedContainer(keyedBy:)`.
  //
  // There is no known case of anything ever actually using the
  // `.nestedUnkeyedContainer()` method.
  case q(String)
  case i(Int)
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension UnparsedValuesEndToEndTests {
  func testUnparsedEnumWithAssociatedValues() {
    AssertParse(Qiqi.self, []) { qiqi in
      XCTAssertFalse(qiqi.qiqiqi)
      XCTAssertEqual(qiqi.qiqii, .q(""))
    }
  }
}

// MARK: Value + nested decodable inheriting class type

private struct Fry: ParsableCommand {
  @Flag var c: Bool = false
  var toksVig: Vig = .init()
}

private class Toks: Codable {
  var a = "hello"
}

private final class Vig: Toks {
  var b = "world"
}

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension UnparsedValuesEndToEndTests {
  func testUnparsedNestedInheritingClassType() {
    AssertParse(Fry.self, []) { fry in
      XCTAssertFalse(fry.c)
      XCTAssertEqual(fry.toksVig.a, "hello")
      XCTAssertEqual(fry.toksVig.b, "world")
    }
  }
}
