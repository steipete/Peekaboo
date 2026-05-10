import PeekabooAutomation
import PeekabooCore

@MainActor
enum RuntimeServiceFactory {
    static func makeLocalServices(options: CommandRuntimeOptions) -> PeekabooServices {
        PeekabooServices(
            inputPolicy: PeekabooAutomation.ConfigurationManager.shared.getUIInputPolicy(
                cliStrategy: options.inputStrategy
            )
        )
    }
}
