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

import ArgumentParser

@main
struct Color: ParsableCommand {
  @Option(help: "Your favorite color.")
  var fav: ColorOptions

  @Option(
    help: .init("Your second favorite color.", discussion: "This is optional."))
  var second: ColorOptions?

  func run() {
    print("My favorite color is \(fav.rawValue)")
    if let second {
      print("...And my second favorite is \(second.rawValue)!")
    }
  }
}

public enum ColorOptions: String, CaseIterable, ExpressibleByArgument {
  case red
  case blue
  case yellow

  public var defaultValueDescription: String {
    switch self {
    case .red:
      return "A red color."
    case .blue:
      return "A blue color."
    case .yellow:
      return "A yellow color."
    }
  }

  public var description: String {
    switch self {
    case .red:
      return "A red color."
    case .blue:
      return "A blue color."
    case .yellow:
      return "A yellow color."
    }
  }
}
