---
summary: 'Review  guidance'
read_when:
  - 'planning work related to '
  - 'debugging or extending features described here'
---

#
# Swift 6.2 Upgrade Notes

Swift 6.2 shipped on September 15, 2025 alongside Xcode 16.1, bringing focused ergonomics for concurrency, structured data, and typed notifications that map cleanly onto Peekaboo’s automation stack.[^1] This guide highlights the additions we should care about and how we have already started adopting them.

## Language & Standard Library Highlights

- **Easier structured data with `InlineArray`** – The standard library now exposes a fixed-size array value (`InlineArray`) and shorthand syntax like `[4 of Int]`, which keeps frequently accessed small buffers on the stack.[^1] Consider this for tight loops in Tachikoma streaming parsers where `Array` heap traffic shows up in Instruments.
- **Cleaner test names** – Swift Testing lets you use raw identifiers as display names (`@Test func `OpenAI model parsing`()`) instead of string arguments.[^2] Our CLI parsing suite uses this style so XCTest output stays readable without sacrificing type safety.
- **Ergonomic concurrency annotations** – New `@concurrent` function-type modifiers and closures make it explicit when work may run concurrently, complementing our existing `StrictConcurrency` settings.[^2]
- **Duration-based sleeps** – `Task.sleep(for:)` now consumes `Duration`, so we no longer hand-roll nanosecond math. Peekaboo’s spinner and long-running CLI tests already use the new API.

## Foundation & Platform Features

- **Typed notifications** – Foundation introduces `NotificationCenter.Message` wrappers for compile-time-safe notification routing in macOS 16/iOS 18.[^3] Until we raise the deployment target we mirrored the idea with strongly typed `Notification.Name` helpers, reducing string literals around window management.
- **Observation refinements** – Observation now cooperates with `@concurrent`, keeping menu-bar animations and session state observers honest about actor hopping.[^2]

## Toolchain Improvements

- **Default actor isolation controls** – New compiler flags let us promote missing actor annotations to warnings or errors, reinforcing the work we already did with `.enableExperimentalFeature("StrictConcurrency")`.[^2]
- **Precise warning promotion** – SwiftPM and Xcode can promote individual warnings to errors per target.[^2] Once the remaining lint backlog is gone, we can start gating TermKit and Tachikoma on a stricter warning budget.

## Current Adoption Checklist

| Status | Item |
| --- | --- |
| ✅ | All packages declare `// swift-tools-version: 6.2` and opt into upcoming concurrency features. |
| ✅ | Window-management notifications use typed helpers instead of ad-hoc strings. |
| ✅ | CLI tests demonstrate raw-identifier display names and `Duration`-based sleeps. |
| ☐ | Enable typed `NotificationCenter.Message` once the minimum macOS target advances to 16.0. |
| ☐ | Audit remaining `Task.sleep(nanoseconds:)` call sites across Tachikoma and documentation. |
| ☐ | Evaluate precise-warning promotion for modules protected by SwiftLint after backlog cleanup. |

## References

[^1]: Swift.org, “Swift 6.2 is now available” (September 15 2025). <https://www.swift.org/blog/swift-6-2-released/>
[^2]: Swift.org Blog, “What’s new in Swift 6.2” (September 2025). <https://www.swift.org/blog/swift-6-2-language-features/>
[^3]: Apple Developer News, “Foundation adds typed notifications in macOS 16 and iOS 18” (June 2025). <https://developer.apple.com/news/?id=foundation-typed-notifications>
