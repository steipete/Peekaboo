# Approachable Concurrency in Peekaboo

Swift 6.2’s “approachable concurrency” mode gives us strict compile-time guarantees (actors, Sendable, isolation inference) without littering every file with annotations. Peekaboo now runs **all** packages—Tachikoma, PeekabooCore, apps, CLIs, examples, and tests—under the same configuration so contributors get consistent diagnostics and we avoid subtle thread-safety regressions.

---

## Goals

- **MainActor-first user code**: Anything that touches UI, AppleScript, accessibility, or shell state defaults to `MainActor` (via `.defaultIsolation(MainActor.self)`).
- **Type-safe concurrency**: `StrictConcurrency`, `ExistentialAny`, and `NonisolatedNonsendingByDefault` put Sendable inference front and center while the Swift 6.2 defaults keep the rest of the “approachable” feature set enabled automatically.
- **Zero “mixed mode” targets**: New targets must adopt the same settings so we don’t reintroduce libraries compiled with looser rules.

---

## Manifest Template

Add this helper to your `Package.swift` (outside `let package = …`):

```swift
let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .defaultIsolation(MainActor.self),
]
```

Then reference it in every target (tests included), appending any target-specific flags:

```swift
swiftSettings: approachableConcurrencySettings + [
    .unsafeFlags(["-parse-as-library"]),
]
```

**Do not** reintroduce `InternalImportsByDefault`; it makes Foundation types appear `internal` and breaks public protocol inheritance (e.g., `LocalizedError`). The Swift 6.2 toolchain already enables the remaining “upcoming” features globally, so declaring them again just triggers warnings. The only current exception to `.defaultIsolation(MainActor.self)` is the `peekaboo` CLI target: ArgumentParser’s synthesized `ParsableCommand` implementations still assume non-actor types, so the CLI target uses the same settings minus `.defaultIsolation`. If Swift/ArgumentParser resolves that limitation we should re-enable the flag.

---

## Coding Guidelines

1. **Keep state inside actors.** Prefer `actor` or `@MainActor` types over `NSLock`. If you must share mutable data, wrap it in an actor (see `DynamicToolRegistry`).
2. **Adopt `any`.** The compiler now warns when using bare existential protocols. Replace `Error` with `any Error`, `StandardizedError` with `any StandardizedError`, etc.
3. **Avoid `@unchecked Sendable`.** Only use it when you’ve manually proven safety. For collections or registries, reach for actors or `ManagedCriticalState`.
4. **Async initializers & factory methods.** With `.defaultIsolation(MainActor.self)` you might need `nonisolated(unsafe)` initializers or dedicated async factories for background work (e.g., `Task.detached` for network clients).
5. **Propagation over erasure.** Use typed errors, enums, and generic wrappers instead of `[String: Any]` or `AnyCodable`.

---

## Migration Checklist for New Targets

1. Import the helper array and apply it to **every** target/test.
2. Run `swift build --build-tests` for the package. Fix:
   - `any` diagnostics
   - actor-isolation violations (e.g., accessing actor state from closures)
   - `Sendable` errors (convert types to structs/enums or mark actors)
3. If you depend on `PeekabooCore` or `Tachikoma`, you inherit the settings automatically—still ensure your target adds the array so SwiftPM doesn’t silently omit the flags.
4. Update `AGENTS.md` or adjacent docs if the target introduces new concurrency guarantees (e.g., background services, detached tasks).

---

## Local Workflow & Poltergeist

Approachable concurrency doesn’t change how we build, but it **amplifies** stale-binary issues. Always let Poltergeist handle incremental builds, and shut it down when you’re applying manifest-wide changes:

1. **Check status** – `npm run poltergeist:status`
2. **Stop when editing manifests** – `npm run poltergeist:stop`
3. **Restart only after builds succeed** – `npm run poltergeist:haunt`

Keeping the daemon off while you edit `Package.swift` files ensures SwiftPM rebuilds with the new flags immediately. (I already ran `npm run poltergeist:stop` for this change; the project no longer has an active daemon.)

---

## Troubleshooting

| Issue | Fix |
| --- | --- |
| `public protocol cannot refine an internal protocol` | Remove `InternalImportsByDefault` and rebuild. |
| `actor-isolated property cannot be referenced` | Capture the actor inside `await` blocks or expose a `nonisolated(unsafe)` getter as a last resort. |
| Tooling hung waiting for `.build` | Another `swift build/test` process may hold the workspace. Use `ps -p <pid>` and wait/terminate before retrying. |
| Massive `Sendable` errors in tests | Prefer value types for fixtures, or mark reference-only mocks as `final actor` to keep isolation simple. |

---

## Expectations Going Forward

- **No opt-out**: Don’t remove or narrow the settings without a compelling compiler bug.
- **Docs first**: If a module truly needs a custom actor model (e.g., background audio DSP), document it here before diverging.
- **Review gate**: Code reviews should reject new targets or packages that omit the shared settings.

Approachable concurrency isn’t a one-time switch—it’s the baseline we build on. Keep this guide handy whenever you add a product, introduce async services, or touch actor-isolated state.***
