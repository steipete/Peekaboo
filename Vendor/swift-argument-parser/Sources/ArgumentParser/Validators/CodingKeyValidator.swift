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

/// A validator that ensures that all arguments have corresponding coding keys.
struct CodingKeyValidator: ParsableArgumentsValidator {
  private struct Validator: Decoder {
    let argumentKeys: [InputKey]

    enum ValidationResult: Swift.Error {
      case success
      case missingCodingKeys([InputKey])
    }

    let codingPath: [CodingKey] = []
    let userInfo: [CodingUserInfoKey: Any] = [:]

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
      fatalError()
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
      fatalError()
    }

    func container<Key>(keyedBy type: Key.Type) throws
      -> KeyedDecodingContainer<Key> where Key: CodingKey
    {
      let missingKeys = argumentKeys.filter { Key(stringValue: $0.name) == nil }
      if missingKeys.isEmpty {
        throw ValidationResult.success
      } else {
        throw ValidationResult.missingCodingKeys(missingKeys)
      }
    }
  }

  /// This error indicates that an option, a flag, or an argument of
  /// a `ParsableArguments` is defined without a corresponding `CodingKey`.
  struct MissingKeysError: ParsableArgumentsValidatorError,
    CustomStringConvertible
  {
    let missingCodingKeys: [InputKey]

    var description: String {
      let resolution = """
        To resolve this error, make sure that all properties have \
        corresponding cases in your custom `CodingKey` enumeration.
        """

      if missingCodingKeys.count > 1 {
        return """
          Arguments \(missingCodingKeys.map({ "`\($0)`" }).joined(separator: ",")) \
          are defined without corresponding `CodingKey`s.

          \(resolution)
          """
      } else {
        return """
          Argument `\(missingCodingKeys[0])` is defined without a \
          corresponding `CodingKey`.

          \(resolution)
          """
      }
    }

    var kind: ValidatorErrorKind {
      .failure
    }
  }

  struct InvalidDecoderError: ParsableArgumentsValidatorError,
    CustomStringConvertible
  {
    let type: ParsableArguments.Type

    var description: String {
      """
      The implementation of `init(from:)` for `\(type)` \
      is not compatible with ArgumentParser. To resolve this issue, make sure \
      that `init(from:)` calls the `container(keyedBy:)` method on the given \
      decoder and decodes each of its properties using the returned decoder.
      """
    }

    var kind: ValidatorErrorKind {
      .failure
    }
  }

  static func validate(_ type: ParsableArguments.Type, parent: InputKey?)
    -> ParsableArgumentsValidatorError?
  {
    let argumentKeys: [InputKey] = Mirror(reflecting: type.init())
      .children
      .compactMap { child in
        guard
          let codingKey = child.label,
          child.value as? ArgumentSetProvider != nil
        else { return nil }

        // Property wrappers have underscore-prefixed names
        return InputKey(name: codingKey, parent: parent)
      }
    guard argumentKeys.count > 0 else {
      return nil
    }
    do {
      let _ = try type.init(from: Validator(argumentKeys: argumentKeys))
      return InvalidDecoderError(type: type)
    } catch let result as Validator.ValidationResult {
      switch result {
      case .missingCodingKeys(let keys):
        return MissingKeysError(missingCodingKeys: keys)
      case .success:
        return nil
      }
    } catch {
      fatalError("Unexpected validation error: \(error)")
    }
  }
}
