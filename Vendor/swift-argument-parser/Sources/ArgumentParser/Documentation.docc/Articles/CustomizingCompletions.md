# Customizing Completions

Provide custom shell completions for your command-line tool's arguments and options.

## Overview

`ArgumentParser` provides default completions for any types that it can. For example, an `@Option` property that is a `CaseIterable` type will automatically have the correct values as completion suggestions.

When declaring an option or argument, you can customize the completions that are offered by specifying a ``CompletionKind``. With this completion kind you can specify that the value should be a file, a directory, or one of a list of strings:

```swift
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

You can define the default completion kind for custom ``ExpressibleByArgument`` types by implementing ``ExpressibleByArgument/defaultCompletionKind-866se``. For example, any arguments or options with this `File` type will automatically use files for completions:

```swift
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

```swift
func listExecutables(_ arguments: [String]) -> [String] {
    // Generate the list of executables in the current directory
}

struct SwiftRun {
    @Option(help: "The target to execute.", completion: .custom(listExecutables))
    var target: String?
}
```

In this example, when a user requests completions for the `--target` option, the completion script runs the `SwiftRun` command-line tool with a special syntax, calling the `listExecutables` function with an array of the arguments given so far.

### Configuring Completion Candidates per Shell

The shells supported for word completion all have different completion candidate formats, as
well as their own different syntaxes and built-in commands.

The `CompletionShell.requesting` singleton (of type `CompletionShell?`) can be read to determine
which shell is requesting completion candidates when evaluating functions that either provide
arguments to a `CompletionKind` creation function, or that are themselves arguments to a
`CompletionKind` creation function.

The `CompletionShell.requestingVersion` singleton (of type `String?`) can be read to determine
the version of the shell that is requesting completion candidates when evaluating functions that
are themselves arguments to a `CompletionKind` creation function.

e.g.:

```swift
struct Tool {
    @Option(completion: .shellCommand(generateCommandPerShell()))
    var x: String?

    @Option(completion: .custom(generateCompletionCandidatesPerShell))
    var y: String?
}

/// Runs when a completion script is generated; results hardcoded into script.
func generateCommandPerShell() -> String {
    switch CompletionShell.requesting {
    case CompletionShell.bash:
        return "bash-specific script"
    case CompletionShell.fish:
        return "fish-specific script"
    case CompletionShell.zsh:
        return "zsh-specific script"
    default:
        // return a universal no-op for unknown shells
        return ":"
    }
}

/// Runs during completion while user is typing command line to use your tool
/// Note that the `Version` struct is not included in Swift Argument Parser
func generateCompletionCandidatesPerShell(_ arguments: [String]) -> [String] {
    switch CompletionShell.requesting {
    case CompletionShell.bash:
        if Version(CompletionShell.requestingVersion).major >= 4 {
            return ["A:in:bash4+:syntax", "B:in:bash4+:syntax", "C:in:bash4+:syntax"]
        } else {
            return ["A:in:bash:syntax", "B:in:bash:syntax", "C:in:bash:syntax"]
        }
    case CompletionShell.fish:
        return ["A:in:fish:syntax", "B:in:bash:syntax", "C:in:bash:syntax"]
    case CompletionShell.zsh:
        return ["A:in:zsh:syntax",  "B:in:zsh:syntax",  "C:in:zsh:syntax"]
    default:
        return []
    }
}
```
