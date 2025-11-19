import Foundation

protocol ScreenCaptureMetricsObserving: Sendable {
    func record(
        operation: String,
        api: ScreenCaptureAPI,
        duration: TimeInterval,
        success: Bool,
        error: (any Error)?)
}

struct NullScreenCaptureMetricsObserver: ScreenCaptureMetricsObserving {
    func record(
        operation _: String,
        api _: ScreenCaptureAPI,
        duration _: TimeInterval,
        success _: Bool,
        error _: (any Error)?)
    {}
}
