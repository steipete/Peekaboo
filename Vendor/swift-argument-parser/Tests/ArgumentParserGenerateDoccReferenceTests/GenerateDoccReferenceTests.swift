//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import ArgumentParserTestHelpers
import XCTest

final class GenerateDoccReferenceTests: XCTestCase {
  #if os(macOS)
  func testCountLinesMarkdownReference() throws {
    guard #available(macOS 12, *) else { return }
    try assertGeneratedReference(command: "count-lines", doccFlavored: false)
  }

  func testCountLinesDoccReference() throws {
    guard #available(macOS 12, *) else { return }
    try assertGeneratedReference(command: "count-lines", doccFlavored: true)
  }
  #endif

  func testColorMarkdownReference() throws {
    try assertGeneratedReference(command: "color", doccFlavored: false)
  }
  func testColorDoccReference() throws {
    try assertGeneratedReference(command: "color", doccFlavored: true)
  }

  func testMathMarkdownReference() throws {
    try assertGeneratedReference(command: "math", doccFlavored: false)
  }
  func testMathDoccReference() throws {
    try assertGeneratedReference(command: "math", doccFlavored: true)
  }

  func testRepeatMarkdownReference() throws {
    try assertGeneratedReference(command: "repeat", doccFlavored: false)
  }
  func testRepeatDoccReference() throws {
    try assertGeneratedReference(command: "repeat", doccFlavored: true)
  }

  func testRollMarkdownReference() throws {
    try assertGeneratedReference(command: "roll", doccFlavored: false)
  }
  func testRollDoccReference() throws {
    try assertGeneratedReference(command: "roll", doccFlavored: true)
  }
}
