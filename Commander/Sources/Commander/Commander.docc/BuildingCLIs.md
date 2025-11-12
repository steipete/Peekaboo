# Building CLIs with Commander

Commander mirrors Swift Argument Parser's ergonomics but is tuned for Peekaboo's
agent workloads. Follow these steps to publish a command that participates in the
runtime router and is fully documented.

## Define the command

```swift
import Commander

@MainActor
struct Screenshot: ParsableCommand {
    @Option(help: "App bundle identifier or friendly name")
    var app: String

    @Flag(help: "Emit JSON instead of human-readable output")
    var json: Bool = false

    static var commandDescription: CommandDescription {
        CommandDescription(
            commandName: "screenshot",
            abstract: "Capture the active window or a specific app",
            discussion: "Wraps ScreenCaptureService with guardrails",
            subcommands: [])
    }

    mutating func run() async throws {
        // bridge into PeekabooCore services here
    }
}
```

Property wrappers automatically register themselves with ``CommandSignature`` via
reflection, so the parser knows which flags, options, or positional arguments to
expect.

## Route subcommands

Aggregate commands by constructing a ``Program`` with ``CommandDescriptor``
values derived from your `ParsableCommand` types.

```swift
let descriptors = [Screenshot.descriptor(), Agent.descriptor()]
let program = Program(descriptors: descriptors)
let invocation = try program.resolve(argv: CommandLine.arguments)
```

An invocation contains the resolved descriptor, raw ``ParsedValues``, and the
command path so you can print breadcrumbs or analytics.

## Generate documentation

From the Commander folder run the DocC plugin:

```bash
swift package --disable-sandbox generate-documentation \
  --package-path Commander \
  --target Commander \
  --output-path .build/Commander.doccarchive
```

You can publish the resulting archive via Xcode's DocC preview, host it with
GitHub Pages, or ingest it into Peekaboo's agent help system.
