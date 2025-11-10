//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if compiler(>=6.0)
#if canImport(FoundationEssentials)
internal import FoundationEssentials
#else
internal import Foundation
#endif
#else
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#endif

extension Error {
  func describe() -> String {
    if let description = (self as? LocalizedError)?.errorDescription {
      return description
    } else {
      #if canImport(FoundationEssentials)
      return String(describing: self)
      #else
      if Swift.type(of: self) is NSError.Type {
        return self.localizedDescription
      } else {
        return String(describing: self)
      }
      #endif
    }
  }
}

enum JSONEncoder {
  static func encode<T: Encodable>(_ value: T) -> String {
    #if canImport(FoundationEssentials)
    let encoder = FoundationEssentials.JSONEncoder()
    #else
    let encoder = Foundation.JSONEncoder()
    #endif
    encoder.outputFormatting = .prettyPrinted
    encoder.outputFormatting.insert(.sortedKeys)
    guard let encoded = try? encoder.encode(value) else { return "" }
    return String(data: encoded, encoding: .utf8) ?? ""
  }
}
