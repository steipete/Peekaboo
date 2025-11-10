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

/// A structure that contains an extended description of the argument.
///
/// For `EnumerableOptionValue` types, the `.enumerated` case encapsulates the
/// necessary information to list each of the possible values and their
/// descriptions. Optionally, users can add a discussion preamble that will be
/// appended to the beginning of the value list section.
///
/// For example, the following `EnumerableOptionValue` type defined in a command
/// could contain an additional discussion block defined in its `ArgumentHelp`:
///
/// ```swift
/// enum Color: String, EnumerableOptionValue {
///   case red
///   case blue
///   case yellow
///
///   public var description: String {
///     switch self {
///        case .red:
///         return "A red color."
///        case. blue:
///         return "A blue color."
///        case .yellow:
///         return "A yellow color."
///     }
///   }
/// }
///
/// struct Example: ParsableCommand {
///   @Option(help: ArgumentHelp(discussion: "A set of available colors."))
///   var color: Color
/// }
/// ```
///
/// To which the printed usage would look like the following:
///
/// ```
/// USAGE: example --color <color>
///
/// OPTIONS:
///    --color <color>
///         A set of available colors.
///         Values:
///           red           - A red color.
///           blue          - A blue color.
///           yellow        - A yellow color.
///    -h, --help           Show help information
/// ```
///
/// Without the additional discussion text:
///
/// ```swift
/// @Option var color: Color
/// ```
///
/// The printed usage would look like the following:
///
/// ```
/// USAGE: example --color <color>
///
/// OPTIONS:
///    --color <color>
///          red           - A red color.
///          blue          - A blue color.
///          yellow        - A yellow color.
///    -h, --help           Show help information
/// ```
///
/// Arrays of enumerable types are also supported and will display the same
/// enumerated format:
///
/// ```swift
/// @Option var colors: [Color] = [.red, .blue]
/// ```
///
/// The printed usage would look like the following:
///
/// ```
/// USAGE: example [--colors <colors> ...]
///
/// OPTIONS:
///    --colors <colors>        (default: red, blue)
///          red           - A red color.
///          blue          - A blue color.
///          yellow        - A yellow color.
///    -h, --help           Show help information
/// ```
///
/// In any case where the argument type is not `EnumerableOptionValue` or an
/// array of `EnumerableOptionValue`, the default implementation will use the
/// `.staticText` case and will print a block of discussion text.
enum ArgumentDiscussion {
  case staticText(String)
  case enumerated(preamble: String? = nil, any ExpressibleByArgument.Type)

  init?(
    _ text: String? = nil, _ options: (any ExpressibleByArgument.Type)? = nil
  ) {
    switch (text, options) {
    case (.some(let text), .some(let options)):
      guard !options.allValueDescriptions.isEmpty else {
        self = .staticText(text)
        return
      }
      self = .enumerated(preamble: text, options)
    case (.some(let text), .none):
      self = .staticText(text)
    case (.none, .some(let options)):
      guard !options.allValueDescriptions.isEmpty else {
        return nil
      }
      self = .enumerated(options)
    default:
      return nil
    }
  }

  var isEnumerated: Bool {
    if case .enumerated = self {
      return true
    }

    return false
  }
}

extension ArgumentDiscussion: Sendable {}

extension ArgumentDiscussion: Hashable {
  static func == (lhs: ArgumentDiscussion, rhs: ArgumentDiscussion) -> Bool {
    switch (lhs, rhs) {
    case (.staticText(let lhsText), .staticText(let rhsText)):
      return lhsText == rhsText
    case (
      .enumerated(let lhsPreamble, let lhsOption),
      .enumerated(preamble: let rhsPreamble, let rhsOption)
    ):
      return (lhsPreamble == rhsPreamble) && (lhsOption == rhsOption)
    default:
      return false
    }
  }

  func hash(into hasher: inout Hasher) {
    switch self {
    case .staticText(let text):
      hasher.combine(text)
    case .enumerated(preamble: let text, let options):
      hasher.combine(text)
      hasher.combine(ObjectIdentifier(options))
    }
  }
}
