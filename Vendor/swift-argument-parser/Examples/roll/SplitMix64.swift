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

struct SplitMix64: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed
  }

  mutating func next() -> UInt64 {
    self.state &+= 0x9e37_79b9_7f4a_7c15
    var z: UInt64 = self.state
    z = (z ^ (z &>> 30)) &* 0xbf58_476d_1ce4_e5b9
    z = (z ^ (z &>> 27)) &* 0x94d0_49bb_1331_11eb
    return z ^ (z &>> 31)
  }
}
