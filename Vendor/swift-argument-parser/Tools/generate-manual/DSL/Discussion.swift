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

import ArgumentParserToolInfo

struct DiscussionText: MDocComponent {
  var discussion: String?
  var allValueStrings: [String]?
  var allValueDescriptions: [String: String]?

  init?(
    discussion: String?,
    allValueStrings: [String]?,
    allValueDescriptions: [String: String]?
  ) {
    if discussion == nil, allValueStrings == nil {
      return nil
    }
    self.discussion = discussion
    self.allValueStrings = allValueStrings
    self.allValueDescriptions = allValueDescriptions
  }

  var body: MDocComponent {
    if let discussion {
      discussion
    }

    if discussion != nil, allValueStrings != nil {
      MDocMacro.ParagraphBreak()
    }

    if let allValueStrings, let allValueDescriptions {
      List {
        for value in allValueStrings {
          //          MDocMacro.ListItem(title: MDocMacro.CommandArgument(arguments: [value]))
          MDocMacro.ListItem(
            title: MDocMacro.CommandArgument(arguments: [value]))
          if let description = allValueDescriptions[value] {
            description
          }
        }
      }
    }
  }
}
