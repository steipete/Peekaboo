# https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser llms-full.txt

## Swift Argument Parser
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser#app-main)

Framework

# ArgumentParser

Straightforward, type-safe argument parsing for Swift.

## [Overview](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Overview)

By using `ArgumentParser`, you can create a command-line interface tool by declaring simple Swift types. Begin by declaring a type that defines the information that you need to collect from the command line. Decorate each stored property with one of `ArgumentParser`‘s property wrappers, declare conformance to [`ParsableCommand`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand), and implement your command’s logic in its `run()` method. For `async` renditions of `run`, declare [`AsyncParsableCommand`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/asyncparsablecommand) conformance instead.

```
import ArgumentParser

@main
struct Repeat: ParsableCommand {
    @Argument(help: "The phrase to repeat.")
    var phrase: String

    @Option(help: "The number of times to repeat 'phrase'.")
    var count: Int? = nil

    mutating func run() throws {
        let repeatCount = count ?? 2
        for _ in 0..<repeatCount {
            print(phrase)
        }
    }
}

```

When a user executes your command, the `ArgumentParser` library parses the command-line arguments, instantiates your command type, and then either calls your `run()` method or exits with a useful message.

![The output of the Repeat command, declared above.](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/images/ArgumentParser/repeat.png)

#### [Additional Resources](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Additional-Resources)

- [`ArgumentParser` on GitHub](https://github.com/apple/swift-argument-parser/)

- [`ArgumentParser` on the Swift Forums](https://forums.swift.org/c/related-projects/argumentparser/60)


## [Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#topics)

### [Essentials](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Essentials)

[Getting Started with ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/gettingstarted)

Learn to set up and customize a simple command-line tool.

[`protocol ParsableCommand`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand)

A type that can be executed as part of a nested tree of commands.

[`protocol AsyncParsableCommand`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/asyncparsablecommand)

A type that can be executed asynchronously, as part of a nested tree of commands.

[Defining Commands and Subcommands](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/commandsandsubcommands)

Break complex command-line tools into a tree of subcommands.

[Customizing Help for Commands](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcommandhelp)

Define your command’s abstract, extended discussion, or usage string, and set the flags used to invoke the help display.

### [Arguments, Options, and Flags](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Arguments-Options-and-Flags)

[Declaring Arguments, Options, and Flags](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/declaringarguments)

Use the `@Argument`, `@Option` and `@Flag` property wrappers to declare the command-line interface for your command.

[`struct Argument`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argument)

A property wrapper that represents a positional command-line argument.

[`struct Option`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/option)

A property wrapper that represents a command-line option.

[`struct Flag`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flag)

A property wrapper that represents a command-line flag.

[`struct OptionGroup`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup)

A wrapper that transparently includes a parsable type.

[`protocol ParsableArguments`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablearguments)

A type that can be parsed from a program’s command-line arguments.

### [Property Customization](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Property-Customization)

[Customizing Help](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizinghelp)

Support your users (and yourself) by providing rich help for arguments, options, and flags.

[`struct ArgumentHelp`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp)

Help information for a command-line argument.

[`struct ArgumentVisibility`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumentvisibility)

Visibility level of an argument’s help.

[`struct NameSpecification`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/namespecification)

A specification for how to represent a property as a command-line argument label.

### [Custom Types](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Custom-Types)

[`protocol ExpressibleByArgument`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/expressiblebyargument)

A type that can be expressed as a command-line argument.

[`protocol EnumerableFlag`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/enumerableflag)

A type that represents the different possible flags to be used by a `@Flag` property.

### [Validation and Errors](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Validation-and-Errors)

[Providing Custom Validation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/validation)

Provide helpful feedback to users when things go wrong.

[`struct ValidationError`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/validationerror)

An error type that is presented to the user as an error with parsing their command-line input.

[`struct CleanExit`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/cleanexit)

An error type that represents a clean (i.e. non-error state) exit of the utility.

[`struct ExitCode`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/exitcode)

An error type that only includes an exit code.

### [Shell Completion Scripts](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Shell-Completion-Scripts)

[Generating and Installing Completion Scripts](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/installingcompletionscripts)

Install shell completion scripts generated by your command-line tool.

[Customizing Completions](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions)

Provide custom shell completions for your command-line tool’s arguments and options.

[`struct CompletionKind`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/completionkind)

The type of completion to use for an argument or option.

### [Advanced Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Advanced-Topics)

[Manual Parsing and Testing](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/manualparsing)

Provide your own array of command-line inputs or work directly with parsed command-line arguments.

[Experimental Features](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/experimentalfeatures)

Learn about ArgumentParser’s experimental features.

### [Structures](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Structures)

[`struct CommandGroup`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/commandgroup)

A set of commands grouped together under a common name.

### [Extended Modules](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser\#Extended-Modules)

[Swift](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/swift)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser#app-top)
- [Overview](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser#Overview)
- [Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser#topics)

Current page is ArgumentParser

|
|

## Customizing Completions
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- Customizing Completions

Article

# Customizing Completions

Provide custom shell completions for your command-line tool’s arguments and options.

## [Overview](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions\#Overview)

`ArgumentParser` provides default completions for any types that it can. For example, an `@Option` property that is a `CaseIterable` type will automatically have the correct values as completion suggestions.

When declaring an option or argument, you can customize the completions that are offered by specifying a [`CompletionKind`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/completionkind). With this completion kind you can specify that the value should be a file, a directory, or one of a list of strings:

```
struct Example: ParsableCommand {
    @Option(help: "The file to read from.", completion: .file())
    var input: String

    @Option(help: "The output directory.", completion: .directory)
    var outputDir: String

    @Option(help: "The preferred file format.", completion: .list(["markdown", "rst"]))
    var format: String

    enum CompressionType: String, CaseIterable, ExpressibleByArgument {
        case zip, gzip
    }

    @Option(help: "The compression type to use.")
    var compression: CompressionType
}

```

The generated completion script will suggest only file names for the `--input` option, only directory names for `--output-dir`, and only the strings `markdown` and `rst` for `--format`. The `--compression` option uses the default completions for a `CaseIterable` type, so the completion script will suggest `zip` and `gzip`.

You can define the default completion kind for custom [`ExpressibleByArgument`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/expressiblebyargument) types by implementing [`defaultCompletionKind`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/expressiblebyargument/defaultcompletionkind). For example, any arguments or options with this `File` type will automatically use files for completions:

```
struct File: Hashable, ExpressibleByArgument {
    var path: String

    init?(argument: String) {
        self.path = argument
    }

    static var defaultCompletionKind: CompletionKind {
        .file()
    }
}

```

For even more control over the suggested completions, you can specify a function that will be called during completion by using the `.custom` completion kind.

```
func listExecutables(_ arguments: [String]) -> [String] {
    // Generate the list of executables in the current directory
}

struct SwiftRun {
    @Option(help: "The target to execute.", completion: .custom(listExecutables))
    var target: String?
}

```

In this example, when a user requests completions for the `--target` option, the completion script runs the `SwiftRun` command-line tool with a special syntax, calling the `listExecutables` function with an array of the arguments given so far.

## [See Also](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions\#see-also)

### [Shell Completion Scripts](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions\#Shell-Completion-Scripts)

[Generating and Installing Completion Scripts](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/installingcompletionscripts)

Install shell completion scripts generated by your command-line tool.

[`struct CompletionKind`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/completionkind)

The type of completion to use for an argument or option.

- [Customizing Completions](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions#app-top)
- [Overview](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions#Overview)
- [See Also](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/customizingcompletions#see-also)

Current page is Customizing Completions

|
|

## OptionGroup Overview
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- OptionGroup

Structure

# OptionGroup

A wrapper that transparently includes a parsable type.

```
@propertyWrapper
struct OptionGroup<Value> where Value : ParsableArguments
```

[OptionGroup.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Properties/OptionGroup.swift#L34 "Open source file for OptionGroup.swift")

## [Overview](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#overview)

Use an option group to include a group of options, flags, or arguments declared in a parsable type.

```
struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong)
    var verbose: Bool

    @Argument var values: [Int]
}

struct Options: ParsableArguments {
    @Option var name: String
    @OptionGroup var globals: GlobalOptions
}

```

The flag and positional arguments declared as part of `GlobalOptions` are included when parsing `Options`.

## [Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#topics)

### [Creating an Option Group](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#Creating-an-Option-Group)

[`init(title: String, visibility: ArgumentVisibility)`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/init(title:visibility:))

Creates a property that represents another parsable type, using the specified title and visibility.

### [Option Group Properties](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#Option-Group-Properties)

[`var title: String`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/title)

The title to use in the help screen for this option group.

### [Infrequently Used APIs](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#Infrequently-Used-APIs)

[`init()`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/init())

Creates a property that represents another parsable type.

Deprecated

[`var wrappedValue: Value`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/wrappedvalue)

The value presented by this property wrapper.

[`var description: String`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/description)

### [Default Implementations](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#Default-Implementations)

[API Reference\\
CustomStringConvertible Implementations](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/customstringconvertible-implementations)

## [Relationships](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#relationships)

### [Conforms To](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#conforms-to)

- `Swift.Copyable`
- `Swift.CustomStringConvertible`
- `Swift.Decodable`
- `Swift.Sendable`

## [See Also](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#see-also)

### [Arguments, Options, and Flags](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup\#Arguments-Options-and-Flags)

[Declaring Arguments, Options, and Flags](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/declaringarguments)

Use the `@Argument`, `@Option` and `@Flag` property wrappers to declare the command-line interface for your command.

[`struct Argument`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argument)

A property wrapper that represents a positional command-line argument.

[`struct Option`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/option)

A property wrapper that represents a command-line option.

[`struct Flag`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flag)

A property wrapper that represents a command-line flag.

[`protocol ParsableArguments`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablearguments)

A type that can be parsed from a program’s command-line arguments.

- [OptionGroup](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup#app-top)
- [Overview](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup#overview)
- [Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup#topics)
- [Relationships](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup#relationships)
- [See Also](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup#see-also)

Current page is OptionGroup

|
|

## ArgumentParser Flag
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flag/wrappedvalue#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [Flag](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flag)
- wrappedValue

Instance Property

# wrappedValue

The value presented by this property wrapper.

```
var wrappedValue: Value { get set }
```

[Flag.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Properties/Flag.swift#L99 "Open source file for Flag.swift")

Current page is wrappedValue

|
|

## chooseLast Flag
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flagexclusivity/chooselast#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [FlagExclusivity](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flagexclusivity)
- chooseLast

Type Property

# chooseLast

The last enumeration case that is provided is used.

```
static var chooseLast: FlagExclusivity { get }
```

[Flag.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Properties/Flag.swift#L186 "Open source file for Flag.swift")

Current page is chooseLast

|
|

## Exclusive Flag Usage
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flagexclusivity/exclusive#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [FlagExclusivity](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flagexclusivity)
- exclusive

Type Property

# exclusive

Only one of the enumeration cases may be provided.

```
static var exclusive: FlagExclusivity { get }
```

[Flag.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Properties/Flag.swift#L176 "Open source file for Flag.swift")

Current page is exclusive

|
|

## ValidationError Message
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/validationerror/message#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ValidationError](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/validationerror)
- message

Instance Property

# message

The error message represented by this instance, this string is presented to the user when a `ValidationError` is thrown from either; `run()`, `validate()` or a transform closure.

```
var message: String { get }
```

[Errors.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Properties/Errors.swift#L18 "Open source file for Errors.swift")

Current page is message

|
|

## Swift Argument Parser
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main()#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ParsableCommand](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand)
- main()

Type Method

# main()

Executes this command, or one of its subcommands, with the program’s command-line arguments.

```
static func main()
```

[ParsableCommand.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Types/ParsableCommand.swift#L174 "Open source file for ParsableCommand.swift")

## [Discussion](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main()\#discussion)

Instead of calling this method directly, you can add `@main` to the root command for your command-line tool.

This method parses an instance of this type, one of its subcommands, or another built-in `ParsableCommand` type, from command-line arguments, and then calls its `run()` method, exiting with a relevant error message if necessary.

## [See Also](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main()\#see-also)

### [Starting the Program](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main()\#Starting-the-Program)

[`static func main([String]?)`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main(_:))

Executes this command, or one of its subcommands, with the given arguments.

- [main()](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main()#app-top)
- [Discussion](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main()#discussion)
- [See Also](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/main()#see-also)

Current page is main()

|
|

## Extended Grapheme Initializer
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/init(extendedgraphemeclusterliteral:)#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ArgumentHelp](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp)
- init(extendedGraphemeClusterLiteral:)

Initializer

# init(extendedGraphemeClusterLiteral:)

Inherited from `ExpressibleByStringLiteral.init(extendedGraphemeClusterLiteral:)`.

ArgumentParserSwift

```
init(extendedGraphemeClusterLiteral value: Self.StringLiteralType)
```

Available when `ExtendedGraphemeClusterLiteralType` is `Self.StringLiteralType`.

Current page is init(extendedGraphemeClusterLiteral:)

|
|

## ArgumentHelp Initializer
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/init(stringliteral:)#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ArgumentHelp](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp)
- init(stringLiteral:)

Initializer

# init(stringLiteral:)

Inherited from `ExpressibleByStringLiteral.init(stringLiteral:)`.

```
init(stringLiteral value: String)
```

[ArgumentHelp.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Properties/ArgumentHelp.swift#L84 "Open source file for ArgumentHelp.swift")

Current page is init(stringLiteral:)

|
|

## Swift run() Method
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand/run()-20aoy#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ParsableCommand](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/parsablecommand)
- run()

Instance Method

# run()

Inherited from `ParsableCommand.run()`.

```
mutating func run() throws
```

[ParsableCommand.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Types/ParsableCommand.swift#L47 "Open source file for ParsableCommand.swift")

Current page is run()

|
|

## FlagInversion Operator
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flaginversion/!=(_:_:)#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [FlagInversion](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/flaginversion)
- !=(\_:\_:)

Operator

# !=(\_:\_:)

Inherited from `Equatable.!=(_:_:)`.

ArgumentParserSwift

```
static func != (lhs: Self, rhs: Self) -> Bool
```

Current page is !=(\_:\_:)

|
|

## Argument Help Initializer
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/init(_:discussion:valuename:visibility:)#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ArgumentHelp](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp)
- init(\_:discussion:valueName:visibility:)

Initializer

# init(\_:discussion:valueName:visibility:)

Creates a new help instance.

```
init(
    _ abstract: String = "",
    discussion: String = "",
    valueName: String? = nil,
    visibility: ArgumentVisibility = .default
)
```

[ArgumentHelp.swift](https://github.com/apple/swift-argument-parser/blob/1.5.1/Sources/ArgumentParser/Parsable%20Properties/ArgumentHelp.swift#L58 "Open source file for ArgumentHelp.swift")

Current page is init(\_:discussion:valueName:visibility:)

|
|

## CustomStringConvertible Implementations
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/customstringconvertible-implementations#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [OptionGroup](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup)
- CustomStringConvertible Implementations

API Collection

# CustomStringConvertible Implementations

## [Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/customstringconvertible-implementations\#topics)

### [Instance Properties](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/customstringconvertible-implementations\#Instance-Properties)

[`var description: String`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/optiongroup/description)

Current page is CustomStringConvertible Implementations

|
|

## Grapheme Cluster Implementations
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/expressiblebyextendedgraphemeclusterliteral-implementations#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ArgumentHelp](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp)
- ExpressibleByExtendedGraphemeClusterLiteral Implementations

API Collection

# ExpressibleByExtendedGraphemeClusterLiteral Implementations

## [Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/expressiblebyextendedgraphemeclusterliteral-implementations\#topics)

### [Initializers](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/expressiblebyextendedgraphemeclusterliteral-implementations\#Initializers)

[`init(unicodeScalarLiteral: Self.ExtendedGraphemeClusterLiteralType)`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/init(unicodescalarliteral:))

Current page is ExpressibleByExtendedGraphemeClusterLiteral Implementations

|
|

## String Literal Implementations
[Skip Navigation](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/expressiblebystringliteral-implementations#app-main)

- [ArgumentParser](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser)
- [ArgumentHelp](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp)
- ExpressibleByStringLiteral Implementations

API Collection

# ExpressibleByStringLiteral Implementations

## [Topics](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/expressiblebystringliteral-implementations\#topics)

### [Initializers](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/expressiblebystringliteral-implementations\#Initializers)

[`init(extendedGraphemeClusterLiteral: Self.StringLiteralType)`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/init(extendedgraphemeclusterliteral:))

[`init(stringLiteral: String)`](https://swiftpackageindex.com/apple/swift-argument-parser/1.5.1/documentation/argumentparser/argumenthelp/init(stringliteral:))

Current page is ExpressibleByStringLiteral Implementations

|
|

