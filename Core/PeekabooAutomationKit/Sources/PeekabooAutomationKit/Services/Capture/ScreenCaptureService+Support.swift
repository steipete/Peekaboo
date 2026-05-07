//
//  ScreenCaptureService+Support.swift
//  PeekabooCore
//

@preconcurrency import AXorcist
import Foundation
@preconcurrency import ScreenCaptureKit

extension SCShareableContent: @retroactive @unchecked Sendable {}
extension SCDisplay: @retroactive @unchecked Sendable {}
extension SCWindow: @retroactive @unchecked Sendable {}

func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T) async throws -> T
{
    try await AXTimeoutHelper.withTimeout(seconds: seconds, operation: operation)
}
