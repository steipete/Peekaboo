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

/// A validator that ensures argument names are unique within a
/// `ParsableArguments` or `ParsableCommand`.
struct UniqueNamesValidator: ParsableArgumentsValidator {
  struct Error: ParsableArgumentsValidatorError, CustomStringConvertible {
    var duplicateNames: [String: Int] = [:]

    var description: String {
      duplicateNames.map { entry in
        """
        Multiple (\(entry.value)) `Option` or `Flag` arguments are named \
        "\(entry.key)".
        """
      }.joined(separator: "\n")
    }

    var kind: ValidatorErrorKind { .failure }
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

    let countedNames: [String: Int] = argSets.reduce(into: [:]) {
      countedNames, args in
      for name in args.content.flatMap({ $0.names }) {
        countedNames[name.synopsisString, default: 0] += 1
      }
    }

    let duplicateNames = countedNames.filter { $0.value > 1 }
    return duplicateNames.isEmpty
      ? nil
      : Error(duplicateNames: duplicateNames)
  }
}
