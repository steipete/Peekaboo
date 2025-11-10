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

extension CommandLine {
  /// Accesses the command line arguments in a concurrency-safe way.
  ///
  /// Workaround for https://github.com/apple/swift/issues/66213
  static let _staticArguments: [String] = Self.arguments
}

#if canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(Darwin)
import Darwin
#elseif canImport(CRT)
@preconcurrency import CRT
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#elseif canImport(Android)
@preconcurrency import Android
#endif

enum Platform {}

// MARK: Environment

extension Platform {
  enum Environment {
    struct Key {
      static let shell = Self(rawValue: "SHELL")
      static let columns = Self(rawValue: "COLUMNS")
      static let lines = Self(rawValue: "LINES")

      /// The name of the environment variable whose value is the name of the shell
      /// for which completions are being requested from a custom completion
      /// handler.
      ///
      /// The environment variable is set in generated completion scripts.
      static let shellName = Self(rawValue: "SAP_SHELL")

      /// The name of the environment variable whose value is the version of the
      /// shell for which completions are being requested from a custom completion
      /// handler.
      ///
      /// The environment variable is set in generated completion scripts.
      static let shellVersion = Self(rawValue: "SAP_SHELL_VERSION")

      var rawValue: String
    }

    @_disfavoredOverload
    static subscript(_ key: Key) -> String? {
      get {
        #if !os(Windows) && !os(WASI)
        guard let cString = getenv(key.rawValue) else { return nil }
        return String(cString: cString)
        #else
        return nil
        #endif
      }
      set {
        #if !os(Windows) && !os(WASI)
        if let newValue = newValue {
          setenv(key.rawValue, newValue, 1)
        } else {
          unsetenv(key.rawValue)
        }
        #endif
      }
    }

    static subscript<Value>(_ key: Key, as _: Value.Type) -> Value?
    where Value: LosslessStringConvertible
    {
      get {
        guard let stringValue = self[key] else { return nil }
        return Value(stringValue)
      }
      set {
        if let newValue = newValue {
          self[key] = newValue.description
        } else {
          self[key] = nil
        }
      }
    }

    static subscript<Value>(_ key: Key, as _: Value.Type) -> Value?
    where Value: RawRepresentable, Value.RawValue == String
    {
      get {
        guard let stringValue = self[key] else { return nil }
        return Value(rawValue: stringValue)
      }
      set {
        if let newValue = newValue {
          self[key] = newValue.rawValue
        } else {
          self[key] = nil
        }
      }
    }
  }
}

// MARK: Shell

extension Platform {
  /// The name of the user's preferred shell, if detectable from the
  /// environment.
  static var shellName: String? {
    #if os(Windows)
    return nil
    #else
    // FIXME: This retrieves the user's preferred shell, not necessarily the one currently in use.
    guard let shellVar = Environment[.shell] else { return nil }
    let shellParts = shellVar.split(separator: "/")
    return shellParts.last.map(String.init)
    #endif
  }
}

// MARK: Exit codes

#if os(Windows)
import func WinSDK.GetStdHandle
import func WinSDK.GetConsoleScreenBufferInfo
import let WinSDK.ERROR_BAD_ARGUMENTS
import let WinSDK.STD_OUTPUT_HANDLE
import struct WinSDK.CONSOLE_SCREEN_BUFFER_INFO
#endif

extension Platform {
  /// The code for successful exit.
  static var exitCodeSuccess: Int32 {
    EXIT_SUCCESS
  }

  /// The code for exit with a general failure.
  static var exitCodeFailure: Int32 {
    EXIT_FAILURE
  }

  /// The code for exit with a validation failure.
  static var exitCodeValidationFailure: Int32 {
    #if os(Windows)
    return ERROR_BAD_ARGUMENTS
    #elseif os(WASI)
    return EXIT_FAILURE
    #else
    return EX_USAGE
    #endif
  }
}

// MARK: Exit function

extension Platform {
  /// Complete execution with the given exit code.
  static func exit(_ code: Int32) -> Never {
    #if canImport(Glibc)
    Glibc.exit(code)
    #elseif canImport(Musl)
    Musl.exit(code)
    #elseif canImport(Darwin)
    Darwin.exit(code)
    #elseif canImport(CRT)
    ucrt._exit(code)
    #elseif canImport(WASILibc)
    WASILibc.exit(code)
    #elseif canImport(Android)
    Android.exit(code)
    #endif
  }
}

// MARK: Standard error

extension Platform {
  /// A type that represents the `stderr` output stream.
  struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
      for byte in string.utf8 { putc(numericCast(byte), stderr) }
    }
  }

  /// The `stderr` output stream.
  static var standardError: StandardError {
    StandardError()
  }
}

// MARK: Terminal size

#if canImport(Glibc) || canImport(Android)
func ioctl(_ a: Int32, _ b: Int32, _ p: UnsafeMutableRawPointer) -> Int32 {
  ioctl(CInt(a), UInt(b), p)
}
#endif

extension Platform {
  /// The default terminal size.
  private static var defaultTerminalSize: (width: Int, height: Int) {
    (width: 80, height: 25)
  }

  /// The terminal size specified by the COLUMNS and LINES overrides
  /// (if present).
  ///
  /// Per the [Linux environ(7) manpage][linenv]:
  ///
  /// ```
  /// * COLUMNS and LINES tell applications about the window size,
  ///   possibly overriding the actual size.
  /// ```
  ///
  /// And the [FreeBSD environ(7) version][bsdenv]:
  ///
  /// ```
  /// COLUMNS    The user's preferred width in column positions for the
  ///            terminal.  Utilities such as ls(1) and who(1) use this
  ///            to format output into columns.   If  unset  or  empty,
  ///            utilities  will use an ioctl(2) call to ask the termi-
  ///            nal driver for the width.
  /// ```
  ///
  /// > Note: Always returns `(nil, nil)` on Windows and WASI.
  ///
  /// - Returns: A tuple consisting of a width found in the `COLUMNS` environment
  ///   variable (or `nil` if the variable is not present) and a height found in
  ///   the `LINES` environment variable (or `nil` if that variable is not present).
  ///
  /// [linenv]: https://man7.org/linux/man-pages/man7/environ.7.html:~:text=COLUMNS
  /// [bsdenv]: https://man.freebsd.org/cgi/man.cgi?environ(7)#:~:text=COLUMNS
  private static func userSpecifiedTerminalSize() -> (width: Int?, height: Int?)
  {
    var width: Int? = nil
    var height: Int? = nil

    #if !os(Windows) && !os(WASI)
    if let columns = Platform.Environment[.columns, as: Int.self] {
      width = columns
    }
    if let lines = Platform.Environment[.lines, as: Int.self] {
      height = lines
    }
    #endif

    return (width: width, height: height)
  }

  /// The current terminal size as reported by the windowing system,
  /// if available.
  ///
  /// Returns (nil, nil) if no reported size is available.
  private static func reportedTerminalSize() -> (width: Int?, height: Int?) {
    #if os(WASI)
    // WASI doesn't yet support terminal size
    return (width: nil, height: nil)
    #elseif os(Windows)
    var csbi = CONSOLE_SCREEN_BUFFER_INFO()
    guard GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi)
    else {
      return (width: nil, height: nil)
    }
    return (
      width: Int(csbi.srWindow.Right - csbi.srWindow.Left) + 1,
      height: Int(csbi.srWindow.Bottom - csbi.srWindow.Top) + 1
    )
    #else
    var w = winsize()

    #if os(OpenBSD)
    // TIOCGWINSZ is a complex macro, so we need the flattened value.
    let tiocgwinsz = Int32(0x4008_7468)
    let err = ioctl(STDOUT_FILENO, tiocgwinsz, &w)
    #elseif canImport(Musl)
    let err = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w)
    #else
    let err = ioctl(STDOUT_FILENO, TIOCGWINSZ, &w)
    #endif
    guard err == 0 else { return (width: nil, height: nil) }

    let width = Int(w.ws_col)
    let height = Int(w.ws_row)

    return (
      width: width > 0 ? width : nil,
      height: height > 0 ? height : nil
    )
    #endif
  }

  /// Returns the current terminal size, or the default if the size is unavailable.
  static func terminalSize() -> (width: Int, height: Int) {
    let specifiedSize = self.userSpecifiedTerminalSize()

    // Avoid needlessly calling ioctl() if a complete override is in effect
    if let specifiedWidth = specifiedSize.width,
      let specifiedHeight = specifiedSize.height
    {
      return (width: specifiedWidth, height: specifiedHeight)
    }

    // Get the size self-reported by the terminal, if available
    let reportedSize = self.reportedTerminalSize()

    // As it isn't required that both width and height always be specified
    // together, either by the user or the terminal itself, they are
    // handled separately.
    return (
      width: specifiedSize.width ?? reportedSize.width
        ?? defaultTerminalSize.width,
      height: specifiedSize.height ?? reportedSize.height
        ?? defaultTerminalSize.height
    )
  }

  /// The current terminal size, or the default if the width is unavailable.
  static var terminalWidth: Int {
    self.terminalSize().width
  }
}
