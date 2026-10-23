import Testing
@testable import PeekabooBridge

struct DesktopObservationWindowTitleAgreementTests {
    @Test
    func `identical titles agree`() {
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Report", "Report", applicationName: "TextEdit"))
    }

    @Test
    func `accessibility title with application suffix matches bare window-server title`() {
        // Chrome reports "Document - Google Chrome" through Accessibility while CoreGraphics
        // reports the bare "Document"; both identify the same window.
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "SM100 - DeepSeek - Google Chrome",
            "SM100 - DeepSeek",
            applicationName: "Google Chrome"))
    }

    @Test
    func `window-server title with application suffix matches bare accessibility title`() {
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "SM100 - DeepSeek",
            "SM100 - DeepSeek - Google Chrome",
            applicationName: "Google Chrome"))
    }

    @Test
    func `surrounding whitespace is ignored`() {
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "  Report  ", "Report", applicationName: "TextEdit"))
    }

    @Test
    func `different documents are rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Document A - Google Chrome", "Document B", applicationName: "Google Chrome"))
    }

    @Test
    func `suffix naming a different application is rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Doc - Safari", "Doc", applicationName: "Google Chrome"))
    }

    @Test
    func `suffix without the separator space is rejected`() {
        // "Doc - Chrome" is not the documented " - <applicationName>" form for "Google Chrome".
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Doc - Chrome", "Doc", applicationName: "Google Chrome"))
    }

    @Test
    func `prefix collision is rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "DocX - Google Chrome", "Doc", applicationName: "Google Chrome"))
    }

    @Test
    func `empty candidate is rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "", "Doc", applicationName: "Google Chrome"))
    }

    @Test
    func `suffix difference without a known application name is rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Doc - Google Chrome", "Doc", applicationName: nil))
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Doc - Google Chrome", "Doc", applicationName: "   "))
    }

    // MARK: - WindowServer middle elision

    /// Captured from a live Chrome window: CoreGraphics elides the middle of the long title
    /// with a single U+2026 while Accessibility retains the full text and its app suffix.
    private static let elidedTitle =
        "Guide for authors - Linguistics \u{2026} | ScienceDirect.com by Elsevier"
    private static let fullAccessibilityTitle =
        "Guide for authors - Linguistics and Education - ISSN 0898-5898 | " +
        "ScienceDirect.com by Elsevier - Google Chrome"

    @Test
    func `window-server elided title matches the full accessibility title`() {
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            Self.fullAccessibilityTitle,
            Self.elidedTitle,
            applicationName: "Google Chrome"))
    }

    @Test
    func `elided title matches the full title regardless of argument order`() {
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            Self.elidedTitle,
            Self.fullAccessibilityTitle,
            applicationName: "Google Chrome"))
    }

    /// Regression: when both layers carry a U+2026, a miss in the first orientation must not
    /// prevent the reverse orientation from matching.
    @Test
    func `elided title matches when both sides contain an ellipsis`() {
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Weekly digest \u{2026} issue 42 and more | Example.com - Google Chrome",
            "Weekly digest \u{2026} issue 42 and \u{2026} | Example.com",
            applicationName: "Google Chrome"))
    }

    @Test
    func `elided titles whose fragments are reordered are rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Weekly digest \u{2026} issue 42 and more | Example.com - Google Chrome",
            "issue 42 and \u{2026} Weekly digest | Example.com",
            applicationName: "Google Chrome"))
    }

    @Test
    func `elided title with unrelated visible fragments is rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Unrelated heading \u{2026} Nope", Self.fullAccessibilityTitle, applicationName: "Google Chrome"))
    }

    @Test
    func `elided title whose tail does not match is rejected`() {
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Guide for authors \u{2026} Different site", Self.fullAccessibilityTitle, applicationName: "Google Chrome"))
    }

    @Test
    func `elided title without a known application name is rejected`() {
        // Without the application name the Accessibility suffix cannot be stripped, so the
        // elided tail cannot be proven to belong to the same title.
        #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            Self.elidedTitle, Self.fullAccessibilityTitle, applicationName: nil))
    }

    @Test
    func `edge or doubled ellipses are not middle elision`() {
        for elided in [
            "Report \u{2026} Site \u{2026}",
            "\u{2026} Report \u{2026} Site",
            "Report \u{2026}\u{2026} Site",
        ] {
            #expect(!PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
                elided,
                "Report confidential Site",
                applicationName: nil))
        }
        #expect(PeekabooBridgeDesktopObservationBinding.windowTitlesAgree(
            "Report \u{2026} Site",
            "Report confidential Site",
            applicationName: nil))
    }
}
