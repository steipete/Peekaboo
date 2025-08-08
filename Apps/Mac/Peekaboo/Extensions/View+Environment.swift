//
//  View+Environment.swift
//  Peekaboo
//

import SwiftUI

extension View {
    /// Add an optional value to the environment
    /// The value must conform to Observable and be a class type (AnyObject)
    @ViewBuilder
    func environmentOptional<T: AnyObject & Observable>(_ value: T?) -> some View {
        if let value {
            self.environment(value)
        } else {
            self
        }
    }
}