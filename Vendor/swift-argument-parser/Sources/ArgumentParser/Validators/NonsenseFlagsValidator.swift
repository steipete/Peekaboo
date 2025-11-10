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

/// A validator that prevents declaring flags that can't be turned off.
struct NonsenseFlagsValidator: ParsableArgumentsValidator {
  struct Error: ParsableArgumentsValidatorError, CustomStringConvertible {
    var names: [String]

    var description: String {
      """
      One or more Boolean flags is declared with an initial value of `true`. \
      This results in the flag always being `true`, no matter whether the user \
      specifies the flag or not.

      To resolve this error, change the default to `false`, provide a value \
      for the `inversion:` parameter, or remove the `@Flag` property wrapper \
      altogether.

      Affected flag(s):
      \(names.joined(separator: "\n"))
      """
    }

    var kind: ValidatorErrorKind { .warning }
  }

  static func validate(_ type: ParsableArguments.Type, parent: InputKey?)
    -> ParsableArgumentsValidatorError?
  {
    let argSets: [ArgumentSet] = Mirror(reflecting: type.init())
      .children
      .compactMap { child in
        guard
          let codingKey = child.label,
          let parsed = child.value as? ArgumentSetProvider
        else { return nil }

        let key = InputKey(name: codingKey, parent: parent)
        return parsed.argumentSet(for: key)
      }

    let nonsenseFlags: [String] = argSets.flatMap { args -> [String] in
      args.compactMap { def in
        if case .nullary = def.update,
          !def.help.isComposite,
          def.help.options.contains(.isOptional),
          def.help.defaultValue == "true"
        {
          return def.unadornedSynopsis
        } else {
          return nil
        }
      }
    }

    return nonsenseFlags.isEmpty
      ? nil
      : Error(names: nonsenseFlags)
  }
}
