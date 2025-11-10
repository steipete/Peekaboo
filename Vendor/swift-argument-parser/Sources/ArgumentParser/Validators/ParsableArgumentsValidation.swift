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

extension ParsableArguments {
  static func _validate(parent: InputKey?) throws {
    let validators: [ParsableArgumentsValidator.Type] = [
      PositionalArgumentsValidator.self,
      CodingKeyValidator.self,
      UniqueNamesValidator.self,
      NonsenseFlagsValidator.self,
    ]
    let errors = validators.compactMap { validator in
      validator.validate(self, parent: parent)
    }
    if errors.count > 0 {
      throw ParsableArgumentsValidationError(
        parsableArgumentsType: self, underlayingErrors: errors)
    }
  }
}

protocol ParsableArgumentsValidator {
  static func validate(_ type: ParsableArguments.Type, parent: InputKey?)
    -> ParsableArgumentsValidatorError?
}

enum ValidatorErrorKind {
  case warning
  case failure
}

protocol ParsableArgumentsValidatorError: Error {
  var kind: ValidatorErrorKind { get }
}

struct ParsableArgumentsValidationError: Error, CustomStringConvertible {
  let parsableArgumentsType: ParsableArguments.Type
  let underlayingErrors: [Error]

  var description: String {
    let errorDescriptions =
      underlayingErrors
      .map {
        "- \($0)"
          .wrapped(to: 68)
          .hangingIndentingEachLine(by: 2)
      }
    return """
      Validation failed for `\(parsableArgumentsType)`:

      \(errorDescriptions.joined(separator: "\n"))
      """
  }
}
