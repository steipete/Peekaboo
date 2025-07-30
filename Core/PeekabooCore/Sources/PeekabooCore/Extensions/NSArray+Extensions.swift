//
//  NSArray+Extensions.swift
//  PeekabooCore
//
//  Created by Peekaboo on 2025-01-30.
//

import Foundation

// MARK: - NSArray Extensions

extension NSArray {
    /// Provides Swift's isEmpty property for NSArray to work around linter issues
    /// The linter sometimes removes this, so we need it in a separate file
    var isEmpty: Bool {
        count == 0
    }
}