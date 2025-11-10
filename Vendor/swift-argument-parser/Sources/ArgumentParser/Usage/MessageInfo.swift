//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

enum MessageInfo {
  case help(text: String)
  case validation(message: String, usage: String, help: String)
  case other(message: String, exitCode: ExitCode)

  init(error: Error, type: ParsableArguments.Type, columns: Int? = nil) {
    var commandStack: [ParsableCommand.Type]
    var parserError: ParserError? = nil

    switch error {
    case let e as CommandError:
      commandStack = e.commandStack
      parserError = e.parserError

      // Exit early on built-in requests
      switch e.parserError {
      case .helpRequested(let visibility):
        self = .help(
          text: HelpGenerator(
            commandStack: e.commandStack, visibility: visibility
          ).rendered(screenWidth: columns))
        return

      case .dumpHelpRequested:
        self = .help(
          text: DumpHelpGenerator(commandStack: e.commandStack).rendered())
        return

      case .versionRequested:
        let versionString =
          commandStack
          .map { $0.configuration.version }
          .last(where: { !$0.isEmpty })
          ?? "Unspecified version"
        self = .help(text: versionString)
        return

      case .completionScriptRequested(let shell):
        do {
          let completionsGenerator = try CompletionsGenerator(
            command: type.asCommand, shellName: shell)
          self = .help(text: completionsGenerator.generateCompletionScript())
          return
        } catch {
          self.init(error: error, type: type)
          return
        }

      case .completionScriptCustomResponse(let output):
        self = .help(text: output)
        return

      default:
        break
      }

    case let e as ParserError:
      // Send ParserErrors back through the CommandError path
      self.init(
        error: CommandError(commandStack: [type.asCommand], parserError: e),
        type: type, columns: columns)
      return

    default:
      commandStack = [type.asCommand]
      // if the error wasn't one of our two Error types, wrap it as a userValidationError
      // to be handled appropriately below
      parserError = .userValidationError(error)
    }

    var usage = HelpGenerator(commandStack: commandStack, visibility: .default)
      .usageMessage()

    let commandNames = commandStack.map { $0._commandName }.joined(
      separator: " ")
    if let helpName = commandStack.getPrimaryHelpName() {
      if !usage.isEmpty {
        usage += "\n"
      }
      usage +=
        "  See '\(commandNames) \(helpName.synopsisString)' for more information."
    }

    // Parsing errors and user-thrown validation errors have the usage
    // string attached. Other errors just get the error message.

    if case .userValidationError(let error) = parserError {
      switch error {
      case let error as ValidationError:
        self = .validation(message: error.message, usage: usage, help: "")
      case let error as CleanExit:
        switch error.base {
        case .helpRequest(let command):
          if let command = command {
            commandStack = CommandParser(type.asCommand).commandStack(
              for: command)
          }
          self = .help(
            text: HelpGenerator(
              commandStack: commandStack, visibility: .default
            ).rendered(screenWidth: columns))
        case .dumpRequest(let command):
          if let command = command {
            commandStack = CommandParser(type.asCommand).commandStack(
              for: command)
          }
          self = .help(
            text: DumpHelpGenerator(commandStack: commandStack).rendered())
        case .message(let message):
          self = .help(text: message)
        }
      case let exitCode as ExitCode:
        self = .other(message: "", exitCode: exitCode)
      default:
        self = .other(message: error.describe(), exitCode: .failure)
      }
    } else if let parserError = parserError {
      let usage: String = {
        guard case ParserError.noArguments = parserError else { return usage }
        return "\n"
          + HelpGenerator(commandStack: [type.asCommand], visibility: .default)
          .rendered(screenWidth: columns)
      }()
      // swift-format-ignore: NeverForceUnwrap
      // FIXME: refactor to avoid force unwrap
      // this requires a lot of non-local reasoning to understand why the force
      // unwrap is safe
      let argumentSet = ArgumentSet(
        commandStack.last!, visibility: .default, parent: nil)
      let message = argumentSet.errorDescription(error: parserError) ?? ""
      let helpAbstract = argumentSet.helpDescription(error: parserError) ?? ""
      self = .validation(message: message, usage: usage, help: helpAbstract)
    } else {
      self = .other(message: String(describing: error), exitCode: .failure)
    }
  }

  var message: String {
    switch self {
    case .help(let text):
      return text
    case .validation(let message, usage: _, help: _):
      return message
    case .other(let message, _):
      return message
    }
  }

  func fullText(for args: ParsableArguments.Type) -> String {
    switch self {
    case .help(let text):
      return text
    case .validation(let message, let usage, let help):
      let helpMessage = help.isEmpty ? "" : "Help:  \(help)\n"
      let errorMessage =
        message.isEmpty ? "" : "\(args._errorLabel): \(message)\n"
      return errorMessage + helpMessage + usage
    case .other(let message, _):
      return message.isEmpty ? "" : "\(args._errorLabel): \(message)"
    }
  }

  var shouldExitCleanly: Bool {
    switch self {
    case .help: return true
    case .validation, .other: return false
    }
  }

  var exitCode: ExitCode {
    switch self {
    case .help: return ExitCode.success
    case .validation: return ExitCode.validationFailure
    case .other(_, let exitCode): return exitCode
    }
  }
}
