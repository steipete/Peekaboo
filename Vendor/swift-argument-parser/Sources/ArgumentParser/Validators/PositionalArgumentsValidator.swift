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

/// A validator for positional argument arrays.
///
/// For positional arguments to be valid, there must be at most one
/// positional array argument, and it must be the last positional argument
/// in the argument list. Any other configuration leads to ambiguity in
/// parsing the arguments.
struct PositionalArgumentsValidator: ParsableArgumentsValidator {
  struct Error: ParsableArgumentsValidatorError, CustomStringConvertible {
    let repeatedPositionalArgument: String

    let positionalArgumentFollowingRepeated: String

    var description: String {
      """
      Can't have a positional argument \
      `\(positionalArgumentFollowingRepeated)` following an array of \
      positional arguments `\(repeatedPositionalArgument)`.
      """
    }

    var kind: ValidatorErrorKind { .failure }
  }

  static func validate(
    _ type: ParsableArguments.Type, parent: InputKey?
  ) -> ParsableArgumentsValidatorError? {
    let sets: [ArgumentSet] = Mirror(reflecting: type.init())
      .children
      .compactMap { child in
        guard
          let codingKey = child.label,
          let parsed = child.value as? ArgumentSetProvider
        else { return nil }

        let key = InputKey(name: codingKey, parent: parent)
        return parsed.argumentSet(for: key)
      }

    guard
      let repeatedPositional = sets.firstIndex(where: {
        $0.firstRepeatedPositionalArgument != nil
      })
    else { return nil }
    guard
      let positionalFollowingRepeated = sets[repeatedPositional...]
        .dropFirst()
        .first(where: { $0.firstPositionalArgument != nil })
    else { return nil }

    // swift-format-ignore: NeverForceUnwrap
    // We know these are non-nil because of the guard statements above.
    let firstRepeatedPositionalArgument: ArgumentDefinition = sets[
      repeatedPositional
    ].firstRepeatedPositionalArgument!
    // swift-format-ignore: NeverForceUnwrap
    let positionalFollowingRepeatedArgument: ArgumentDefinition =
      positionalFollowingRepeated.firstPositionalArgument!
    // swift-format-ignore: NeverForceUnwrap
    return Error(
      repeatedPositionalArgument: firstRepeatedPositionalArgument.help.keys
        .first!.name,
      positionalArgumentFollowingRepeated: positionalFollowingRepeatedArgument
        .help.keys.first!.name)
  }
}

extension ArgumentSet {
  fileprivate var firstPositionalArgument: ArgumentDefinition? {
    content.first(where: { $0.isPositional })
  }

  fileprivate var firstRepeatedPositionalArgument: ArgumentDefinition? {
    content.first(where: { $0.isRepeatingPositional })
  }
}
