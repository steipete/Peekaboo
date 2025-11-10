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

import XCTest

@testable import ArgumentParser

final class ExitCodeTests: XCTestCase {}

// MARK: -

// swift-format-ignore: AlwaysUseLowerCamelCase
// https://github.com/apple/swift-argument-parser/issues/710
extension ExitCodeTests {
  struct A: ParsableArguments {}
  struct E: Error {}
  struct C: ParsableCommand {
    static let configuration = CommandConfiguration(version: "v1")
  }

  func testExitCodes() {
    XCTAssertEqual(ExitCode.failure, A.exitCode(for: E()))
    XCTAssertEqual(
      ExitCode.validationFailure, A.exitCode(for: ValidationError("")))

    do {
      _ = try A.parse(["-h"])
      XCTFail("Didn't throw help request error.")
    } catch {
      XCTAssertEqual(ExitCode.success, A.exitCode(for: error))
    }

    do {
      _ = try A.parse(["--version"])
      XCTFail("Didn't throw unrecognized --version error.")
    } catch {
      XCTAssertEqual(ExitCode.validationFailure, A.exitCode(for: error))
    }

    do {
      _ = try C.parse(["--version"])
      XCTFail("Didn't throw version request error.")
    } catch {
      XCTAssertEqual(ExitCode.success, C.exitCode(for: error))
    }
  }

  func testExitCode_Success() {
    XCTAssertFalse(A.exitCode(for: E()).isSuccess)
    XCTAssertFalse(A.exitCode(for: ValidationError("")).isSuccess)

    do {
      _ = try A.parse(["-h"])
      XCTFail("Didn't throw help request error.")
    } catch {
      XCTAssertTrue(A.exitCode(for: error).isSuccess)
    }

    do {
      _ = try A.parse(["--version"])
      XCTFail("Didn't throw unrecognized --version error.")
    } catch {
      XCTAssertFalse(A.exitCode(for: error).isSuccess)
    }

    do {
      _ = try C.parse(["--version"])
      XCTFail("Didn't throw version request error.")
    } catch {
      XCTAssertTrue(C.exitCode(for: error).isSuccess)
    }
  }
}

// MARK: - NSError tests

extension ExitCodeTests {
  func testNSErrorIsHandled() {
    struct NSErrorCommand: ParsableCommand {
      static let message =
        "The file “foo/bar” couldn’t be opened because there is no such file"

      static let fileNotFoundNSError = NSError(
        domain: "TestError",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: Self.message])
    }
    XCTAssertEqual(
      NSErrorCommand.exitCode(for: NSErrorCommand.fileNotFoundNSError),
      ExitCode(rawValue: 1))

    #if canImport(FoundationEssentials)
    let prefix = "Error Domain=TestError Code=1 \"(null)\""
    #if compiler(<6.1)
    XCTAssertEqual(
      NSErrorCommand.message(for: NSErrorCommand.fileNotFoundNSError),
      "\(prefix)")
    #else
    XCTAssertEqual(
      NSErrorCommand.message(for: NSErrorCommand.fileNotFoundNSError),
      "\(prefix)UserInfo={NSLocalizedDescription=\(NSErrorCommand.message)}"
    )
    #endif
    #else
    XCTAssertEqual(
      NSErrorCommand.message(for: NSErrorCommand.fileNotFoundNSError),
      NSErrorCommand.message)
    #endif
  }
}
