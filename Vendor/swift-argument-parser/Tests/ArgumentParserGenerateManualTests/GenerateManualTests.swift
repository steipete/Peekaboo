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

final class GenerateManualTests: XCTestCase {
  #if os(macOS)
  func testCountLinesSinglePageManual() throws {
    guard #available(macOS 12, *) else { return }
    try assertGenerateManual(multiPage: false, command: "count-lines")
  }

  func testCountLinesMultiPageManual() throws {
    guard #available(macOS 12, *) else { return }
    try assertGenerateManual(multiPage: true, command: "count-lines")
  }
  #endif

  func testColorSinglePageManual() throws {
    try assertGenerateManual(multiPage: false, command: "color")
  }

  func testColorMultiPageManual() throws {
    try assertGenerateManual(multiPage: true, command: "color")
  }

  func testMathSinglePageManual() throws {
    try assertGenerateManual(multiPage: false, command: "math")
  }

  func testMathMultiPageManual() throws {
    try assertGenerateManual(multiPage: true, command: "math")
  }

  func testRepeatSinglePageManual() throws {
    try assertGenerateManual(multiPage: false, command: "repeat")
  }

  func testRepeatMultiPageManual() throws {
    try assertGenerateManual(multiPage: true, command: "repeat")
  }

  func testRollSinglePageManual() throws {
    try assertGenerateManual(multiPage: false, command: "roll")
  }

  func testRollMultiPageManual() throws {
    try assertGenerateManual(multiPage: true, command: "roll")
  }
}
