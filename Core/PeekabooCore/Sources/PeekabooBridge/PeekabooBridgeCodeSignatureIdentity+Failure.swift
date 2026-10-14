import Foundation
import Security

extension PeekabooBridgeCodeSignatureIdentity {
    enum SigningValidationFailure: Error, LocalizedError, Equatable, Sendable {
        case liveCDHashUnavailable
        case liveCDHashChanged
        case guestCodeLookupFailed(OSStatus)
        case staticCodeLookupFailed(OSStatus)
        case signingInformationUnavailable
        case staticCDHashUnavailable
        case staticCDHashMismatch
        case staticIdentifierOrTeamUnavailable
        case invalidAnchoredRequirement
        case anchoredValidationUnavailable
        case liveAnchoredRequirementNotSatisfied(OSStatus)
        case staticAnchoredRequirementNotSatisfied(OSStatus)
        case staticIdentifierMismatch
        case staticTeamMismatch

        var errorDescription: String? {
            switch self {
            case .liveCDHashUnavailable:
                "live kernel CDHash is unavailable"
            case .liveCDHashChanged:
                "live kernel CDHash changed during signing validation"
            case let .guestCodeLookupFailed(code):
                "audit-token guest code lookup failed (OSStatus \(code))"
            case let .staticCodeLookupFailed(code):
                "static code lookup failed (OSStatus \(code))"
            case .signingInformationUnavailable:
                "static signing information lookup failed"
            case .staticCDHashUnavailable:
                "static executable CDHash is unavailable or invalid"
            case .staticCDHashMismatch:
                "static executable CDHash differs from the live CDHash (executable may have been replaced on disk)"
            case .staticIdentifierOrTeamUnavailable:
                "static signing identifier or Team ID is unavailable"
            case .invalidAnchoredRequirement:
                "Apple-anchored signing requirement could not be constructed"
            case .anchoredValidationUnavailable:
                "Apple-anchored signature validation did not return an identity"
            case let .liveAnchoredRequirementNotSatisfied(code):
                "live code did not satisfy the Apple-anchored requirement (OSStatus \(code))"
            case let .staticAnchoredRequirementNotSatisfied(code):
                "static code did not satisfy the Apple-anchored requirement (OSStatus \(code))"
            case .staticIdentifierMismatch:
                "static signing identifier differs from the validated identity"
            case .staticTeamMismatch:
                "static signing Team ID differs from the validated identity"
            }
        }
    }
}
