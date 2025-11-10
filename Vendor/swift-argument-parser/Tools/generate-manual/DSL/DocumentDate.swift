//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import ArgumentParserToolInfo
import Foundation

struct DocumentDate: MDocComponent {
  private var month: String
  private var day: Int
  private var year: Int

  init(date: Date) {
    let calendar = Calendar(identifier: .iso8601)
    // swift-format-ignore: NeverForceUnwrap
    // Statically known valid key
    let timeZone = TimeZone(identifier: "UTC")!
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = timeZone
    formatter.dateFormat = "MMMM"
    self.month = formatter.string(from: date)
    let components = calendar.dateComponents(in: timeZone, from: date)
    // FIXME: emit a diagnostic if this fails.
    self.day = components.day ?? 1
    self.year = components.year ?? 1970
  }

  var body: MDocComponent {
    MDocMacro.DocumentDate(day: day, month: month, year: year)
  }
}
