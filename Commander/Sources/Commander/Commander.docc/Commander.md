# ``Commander``

Build Swift command-line tools with strongly typed arguments, expressive property
wrappers, and approachable concurrency.

Commander replaces ad-hoc parsing with a reflection-driven signature builder and a
tiny runtime so you can focus on what the command does, not how to route `argv`.

## Highlights

- Compose commands from `ParsableCommand` types that encapsulate configuration,
  validation, and async execution.
- Describe options, flags, and arguments declaratively using property wrappers.
- Execute subcommands with the lightweight ``Program`` router or reuse the
  ``CommandParser`` directly when you only need parsing.
- Generate DocC documentation (this catalog) so downstream apps can inspect the
  available commands and flags.

## Topics

### Getting Started

- <doc:BuildingCLIs>

### Runtime Entry Points

- ``ParsableCommand``
- ``CommandDescription``
- ``Program``
- ``CommandInvocation``

### Signature Building

- ``CommandSignature``
- ``OptionDefinition``
- ``FlagDefinition``
- ``ArgumentDefinition``

### Parsing

- ``CommandParser``
- ``ParsedValues``
- ``CommanderError``

### Property Wrappers

- ``Option``
- ``Argument``
- ``Flag``
- ``OptionGroup``

### Supporting Types

- ``NameSpecification``
- ``CommanderName``
- ``ExpressibleFromArgument``
- ``OptionParsingStrategy``
- ``ValidationError``
- ``ExitCode``
