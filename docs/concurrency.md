---
summary: 'Practical guide to Swift 6.2 approachable concurrency'
read_when:
  - Enabling default actor isolation in a target
  - Deciding where to use @concurrent or nonisolated async
---

# Swift 6.2 Approachable Concurrency: No-Nonsense Guide

Below is a practical, no-nonsense guide to Swift 6.2’s *approachable concurrency*: what changed, how to enable it, and how to use it without tripping over yourself.

---

## TL;DR

* **Single-threaded by default (if you choose):** New build settings let you run your target on the **MainActor by default**, so most code is serialized unless you opt in to parallelism. Great for UI targets. ([Swift.org][1])
* **Opt-in parallelism:** Use the new **`@concurrent`** attribute to explicitly hop off the current actor (e.g., the main actor) for work that should run on the concurrent thread pool. ([Swift.org][1])
* **More intuitive async semantics (optional flag):** Swift 6.2 ships with a build setting that makes **`nonisolated async` functions inherit the caller’s actor**; enable it when you’re ready. Migration tooling in Xcode 26 helps you adopt it. ([Swift.org][1])
* **Strict checks you can actually adopt:** Turn on **Complete** concurrency checking to find data races, module-by-module. ([Swift.org][2])
* **SPM support:** For packages, set **`.defaultIsolation(MainActor.self)`** per target to get the same “single-threaded by default” feel. ([Apple Developer][3])

---

## 0) Switch the model on (safely)

**For Xcode targets (app/UI):**

* In Build Settings, set **Default Actor Isolation = MainActor**. New projects often start this way already; older ones need opting in. ([Apple Developer][4])

**For Swift Package targets:**

```swift
// Package.swift (tools-version: 6.2)
.target(
  name: "AppUI",
  swiftSettings: [
    .defaultIsolation(MainActor.self)   // SwiftPM 6.2+
  ]
)
```

This mirrors the Xcode setting at the package/target level. By default, packages remain **nonisolated** unless you set it. ([Apple Developer][3])

**Turn on strict checks (gradually):**

* Xcode: **Strict Concurrency Checking = Complete**, or in configs: `SWIFT_STRICT_CONCURRENCY = complete`
* SwiftPM (temporary): `swift build -Xswiftc -strict-concurrency=complete`

Do it module-by-module to keep things moving. ([Swift.org][2])

**Optional flag for clearer async semantics:**

* Enable the shipping build setting that makes **`nonisolated async` inherit the caller’s actor**. Xcode 26 / Swift 6.2 has guidance and fix-its for this. Use it once you understand the impact. ([Swift.org][1])

---

## 1) New mental model

* **“Single-threaded unless requested”:** With default isolation = **MainActor**, unannotated code is treated as main-actor isolated. No more littering code with `@MainActor` just to make the compiler happy. ([Swift.org][1])
* **Async ≠ “background”:** `async` functions on the main actor still run on the main actor until a suspension point; they *don’t* block the actor while awaiting. Use **`@concurrent`** to *explicitly* offload heavy work. ([Swift.org][1])
* **`@concurrent` as your “parallelism switch”:** Put it on functions that should run on the concurrent pool so you keep the main actor free. This removes the need for ad-hoc `Task.detached {}` in most cases. ([Swift.org][1])
* **(Flag-enabled) `nonisolated async` inherits the caller’s actor:** Fewer surprising hops to a generic executor when you call methods from main-actor contexts. ([Swift.org][1])

---

## 2) Day-to-day patterns

### A. UI first, heavy work explicit

```swift
// Target has Default Actor Isolation = MainActor
struct ProfileViewModel {
  // implicitly main-actor isolated members

  func loadProfile() async throws -> Profile {
    let data = try await fetchProfileData()
    let profile = try await parseProfile(data)
    return profile
  }

  @concurrent
  func parseProfile(_ data: Data) async throws -> Profile {
    try await decodeProfile(data)
  }
}
```

### B. Networking helpers

```swift
enum API {
  @concurrent
  static func fetchJSON<T: Decodable>(_ url: URL) async throws -> T {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(T.self, from: data)
  }
}
```

### C. Batching work: `async let` vs. task groups

* `async let` for small, fixed sets; task groups for dynamic fan-out.

### D. Cancellation & timeouts

* Check `Task.isCancelled`, wrap long work in `withTaskCancellationHandler`, and add timeouts where needed.

### E. Avoid `Task.detached` by default

* Prefer `Task { }` (inherits actor context). Reach for `Task.detached` only when you truly need a detached context; `@concurrent` handles most heavy lifting.

---

## 3) Structuring state: actors, singletons, globals

* Wrap mutable state in `actor`s or keep it main-actor isolated. Example:

```swift
actor ImageCache {
  private var store: [URL: Image] = [:]
  func get(_ url: URL) -> Image? { store[url] }
  func set(_ url: URL, _ image: Image) { store[url] = image }
}
```

---

## 4) `nonisolated`, `Sendable`, etc.

* Prefer value types and `Sendable`. Use `@unchecked Sendable` only with comments that explain the safety argument. ([Swift.org][2])
* `nonisolated async` + the Swift 6.2 inheritance flag makes most calls line up with caller context; `@concurrent` is still how you opt into parallelism. ([Swift.org][1])

---

## 5) Packages vs. app targets

* App targets: flip **Default Actor Isolation = MainActor**. ([Apple Developer][4])
* Packages: opt in per target with `.defaultIsolation(MainActor.self)` when that target really is UI/single-threaded. Leave core libraries nonisolated unless they must serialize. ([Apple Developer][3])

---

## 6) Migration playbook

1. Turn on strict checking (warnings) one module at a time. ([Swift.org][2])
2. Enable default MainActor isolation on app targets.
3. For SwiftPM, add `.defaultIsolation(MainActor.self)` selectively. ([Apple Developer][3])
4. Adopt the `nonisolated async` inheritance feature when ready. ([Swift.org][1])
5. Refactor shared mutable state into actors or clearly documented singletons.
6. Replace GCD hops with structured concurrency.
7. Name tasks to leverage 6.2’s async debugging improvements. ([Swift.org][1])

---

## 7) Do’s & Don’ts

**Do**

* Use default MainActor isolation for UI modules.
* Fence heavy work with `@concurrent`.
* Prefer structured concurrency primitives.
* Ensure cross-actor data is `Sendable`.

**Don’t**

* Assume `async` means “background thread.”
* Spam `Task.detached { }`.
* Lean on `nonisolated(unsafe)` except as a temporary migration escape hatch.

---

## 8) Extra goodies in 6.2

* Migration tooling and diagnostics for the new Swift 6.2 features (e.g., nonisolated-async inheritance). ([Swift.org][1])
* Type-safe Foundation notifications with explicit actor/async semantics. ([Swift.org][1])
* Better async debugging (named tasks show up in LLDB). ([Swift.org][1])

---

## 9) Worked example

```swift
// Target defaultIsolation = MainActor
struct PhotosViewModel {
  private let cache = ImageCache()

  func loadThumbnails(for urls: [URL]) async throws -> [CGImage] {
    return try await withThrowingTaskGroup(of: CGImage.self) { group in
      for url in urls {
        group.addTask {
          if let cached = await cache.get(url) { return cached }
          let image = try await fetchAndDecode(url)
          await cache.set(url, image)
          return image
        }
      }
      var images: [CGImage] = []
      for try await img in group { images.append(img) }
      return images
    }
  }

  @concurrent
  private func fetchAndDecode(_ url: URL) async throws -> CGImage {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try decode(data)
  }
}
```

---

## References

1. [Swift 6.2 Release Notes][1]
2. [Enabling Complete Concurrency Checking][2]
3. [SwiftPM `.defaultIsolation` setting][3]
4. [What’s New in Swift (Apple)][4]
5. [Swift Forums: package isolation defaults][5]

[1]: https://swift.org/blog/swift-6.2-released/
[2]: https://swift.org/documentation/concurrency/
[3]: https://developer.apple.com/documentation/packagedescription/swiftsetting/defaultisolation(_:_:)
[4]: https://developer.apple.com/swift/whats-new/
[5]: https://forums.swift.org/t/what-is-the-default-isolation-mode-for-swift-packages-6-2/80453
