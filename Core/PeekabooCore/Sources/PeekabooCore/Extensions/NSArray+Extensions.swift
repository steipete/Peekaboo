//
//  NSArray+Extensions.swift
//  PeekabooCore
//
//  Created by Peekaboo on 2025-01-30.
//
//  \(AgentDisplayTokens.Status.warning)  CRITICAL: DO NOT MODIFY THIS FILE
//  This file is excluded from SwiftFormat and SwiftLint to prevent infinite recursion bugs.
//  Any changes to isEmpty could cause stack overflow crashes.
//

import Foundation

// MARK: - NSArray Extensions

extension NSArray {
    /// Provides Swift's isEmpty property for NSArray to work around linter issues
    /// The linter sometimes removes this, so we need it in a separate file
    /// 
    /// \(AgentDisplayTokens.Status.warning)  WARNING: Do not change `count == 0` to `isEmpty` - it will cause infinite recursion!
    var isEmpty: Bool {
        count == 0  // Must use count, not isEmpty (would cause infinite recursion)
    }
}
