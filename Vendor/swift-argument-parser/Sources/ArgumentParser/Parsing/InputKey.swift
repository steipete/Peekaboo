//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

/// Represents the path to a parsed field, annotated with ``Flag``, ``Option``
/// or ``Argument``.
///
/// Fields that are directly declared on a ``ParsableCommand`` have a path of
/// length 1, while fields that are declared indirectly (and included via an
/// option group) have longer paths.
struct InputKey: Hashable {
  /// The name of the input key.
  var name: String

  /// The path through the field's parents, if any.
  var path: [String]

  /// The full path of the field.
  var fullPath: [String] { path + [name] }

  /// Constructs a new input key, cleaning the name, with the specified parent.
  ///
  /// - Parameters:
  ///   - name: The name of the key.
  ///   - parent: The input key of the parent.
  init(name: String, parent: InputKey?) {
    // Property wrappers have underscore-prefixed names, so we remove the
    // leading `_`, if present.
    self.name =
      name.first == "_"
      ? String(name.dropFirst(1))
      : name
    self.path = parent?.fullPath ?? []
  }

  /// Constructs a new input key from the given coding key and parent path.
  ///
  /// - Parameters:
  ///   - codingKey: The base ``CodingKey``. Leading underscores in `codingKey`
  ///     is preserved.
  ///   - path: The list of ``CodingKey`` values that lead to this one. `path`
  ///     may be empty.
  init(codingKey: CodingKey, path: [CodingKey]) {
    self.name = codingKey.stringValue
    self.path = path.map { $0.stringValue }
  }
}

extension InputKey: CustomStringConvertible {
  var description: String {
    fullPathString
  }
}

extension InputKey {
  private static var separator: Character { "." }

  var fullPathString: String {
    fullPath.joined(separator: .init(Self.separator))
  }

  init?(fullPathString: String) {
    let fullPath = fullPathString.split(separator: Self.separator).map(
      String.init)

    guard let name = fullPath.last else { return nil }

    self.name = name
    self.path = fullPath.dropLast()
  }
}
