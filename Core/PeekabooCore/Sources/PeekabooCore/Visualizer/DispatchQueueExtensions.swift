//
//  DispatchQueueExtensions.swift
//  PeekabooCore
//

import Foundation

extension DispatchQueue {
    /// Returns the label of the current queue if available
    static var currentLabel: String? {
        let label = __dispatch_queue_get_label(nil)
        return String(cString: label)
    }
}
