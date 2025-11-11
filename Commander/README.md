# Commander

Commander is Peekaboo's Swift-native command-line framework. It combines declarative property wrappers, a lightweight parser/router, and runtime helpers that integrate tightly with async/await + approachable concurrency. We extracted it into its own Swift package so other targets (AXorcist, Tachikoma, the CLI examples) can share the same parsing stack without carrying a fork of Apple's `swift-argument-parser`.

## Highlights

- **Property-wrapper ergonomics** – `@Option`, `@Argument`, `@Flag`, and `@OptionGroup` mirror the Swift Argument Parser API but simply register metadata. You keep writing declarative commands while Commander handles parsing and validation centrally.
- **Command signatures everywhere** – `CommandSignature` reflects every option/flag/argument so docs, help output, agent metadata, and tests all rely on the exact same definitions.
- **Program router** – `Program.resolve(argv:)` walks the descriptor tree (root command → subcommand → default subcommand) and produces a `CommandInvocation` with parsed values and the fully-qualified path.
- **Binder APIs** – `CommanderCLIBinder` (living in PeekabooCLI) shows how to hydrate existing command structs by conforming them to `CommanderBindableCommand`. This keeps runtime logic untouched while swapping in Commander incrementally.
- **Approachable concurrency ready** – the package enables `StrictConcurrency`, `ExistentialAny`, and `NonisolatedNonsendingByDefault` so anything that depends on Commander inherits Peekaboo's concurrency guarantees.

## Getting Started

Add Commander as a local dependency (it currently lives in `/Commander` inside the Peekaboo repo):

```swift
// Package.swift
dependencies: [
    .package(path: "../Commander"),
    // ...
],
targets: [
    .executableTarget(
        name: "my-cli",
        dependencies: [
            .product(name: "Commander", package: "Commander")
        ]
    )
]
```

Then declare your command using the familiar property-wrapper style:

```swift
import Commander

@MainActor
struct ScreenshotCommand: ParsableCommand {
    @Argument(help: "Output path") var path: String
    @Option(help: "Target display index") var display: Int?
    @Flag(help: "Emit JSON output") var json = false

    static var configuration = CommandConfiguration(
        commandName: "capture",
        abstract: "Capture a screenshot"
    )

    mutating func run() async throws {
        // perform work…
    }
}
```

If you need more control over how parsed values reach your command type, conform to `CommanderBindableCommand` and use the helper APIs (`decodeOption`, `makeFocusOptions`, etc.). PeekabooCLI's window/agent commands are good examples.

## Repository Layout

- `Sources/Commander` – Core types (property wrappers, tokenizer, parser, program descriptors, metadata helpers).
- `Tests/CommanderTests` – Unit tests for the parser/router plus tokenizer edge cases. Run them with `swift test --package-path Commander`.

## Contributing

Commander is developed alongside Peekaboo. If you need an API or notice a bug, open an issue/PR in https://github.com/steipete/Commander or in the main Peekaboo repository—whichever is more convenient. Please include repro steps and any command metadata involved so we can extend the shared test suites.

## License

Commander inherits Peekaboo's license. Refer to the root `LICENSE` file in this repository for the exact terms.
