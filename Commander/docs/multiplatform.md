---
summary: 'Commander multiplatform support log'
read_when:
  - enabling Commander on additional OS targets
  - modifying Commander CI coverage
---

# Commander Multiplatform Tracking

## Current Status (November 11, 2025)
- **Supported platforms:** macOS 14+, iOS 17+, tvOS 17+, watchOS 10+ via `Package.swift` declarations; Linux, Android, and Windows remain unrestricted because SwiftPM only constrains Apple-family targets explicitly and treats everything else as implicitly supported.¹
- **Portability audit:** Commander exclusively depends on `Foundation` and concurrency features already available in Swift 6, so no conditional compilation was required.
- **Testing coverage:** `CommanderTests` run natively on macOS, Linux, and Windows. Apple simulator builds validate the iOS/tvOS/watchOS triples. Android builds rely on `swift sdk install` with Skip's `swift-android-action` wrapper.

> ¹ See [Swift Package Manager Platform Support](https://developer.apple.com/documentation/swift_packages/supportedplatform), which documents that only Apple OS minimums are declared in `Package.swift` and other platforms remain unconstrained.

## Implementation Checklist

| Item | Status | Notes |
| --- | --- | --- |
| Declare Apple platform minimums in `Package.swift` | ✅ | Uses `.macOS(.v14)`, `.iOS(.v17)`, `.tvOS(.v17)`, `.watchOS(.v10)`
| Verify Linux/Windows portability of sources/tests | ✅ | Host-only APIs avoided; runs via `swift test --package-path Commander` on those OSes
| Validate Apple simulator builds | ✅ | `swift build --build-tests` with `-Xswiftc -sdk …`/`-Xswiftc -target …` for iOS/tvOS/watchOS as described [on Swift Forums](https://forums.swift.org/t/how-to-build-ios-apps-on-linux-with-swift-package/66601/3)
| Add Android cross-compilation step | ✅ | Uses `swift sdk install` (per [Swift.org SDK announcement](https://www.swift.org/blog/nightly-swift-sdk-for-android/)) together with [`skiptools/swift-android-action`](https://github.com/skiptools/swift-android-action)
| Standalone Commander workflow | ✅ | `.github/workflows/commander-multiplatform.yml` fan-out matrix covers macOS, Apple simulators, Linux, Windows, and Android

## CI Design Highlights
- **macOS host tests:** Run `swift test` directly on `macos-15` (new GitHub Actions image announced [here](https://github.blog/changelog/2025-04-10-github-actions-macos-15-and-windows-2025-images-are-now-generally-available/)).
- **Apple simulator builds:** Each matrix entry resolves the proper SDK via `xcrun --sdk <name> --show-sdk-path` and forwards both `-sdk` and `-target` flags to invoke the right triple, mirroring the Swift Forum guidance linked above.
- **Linux & Windows:** Use [`SwiftyLab/setup-swift`](https://github.com/SwiftyLab/setup-swift) to install Swift 6+ toolchains on `ubuntu-24.04` and `windows-2025`, then execute `swift test --package-path Commander`.
- **Android:** `swift sdk install` preps the nightly Android SDKs and `skiptools/swift-android-action@v2` orchestrates the build/test run under QEMU, matching the Skip tooling docs.

## Follow-Ups
1. Add smoke targets for visionOS once Peekaboo formally adopts it.
2. Expand the test suite with parser edge cases so non-macOS runs provide more value.
3. Publish a reusable GitHub Actions composite to share these steps with Tachikoma/PeekabooCore once Commander graduates to its own repository.
