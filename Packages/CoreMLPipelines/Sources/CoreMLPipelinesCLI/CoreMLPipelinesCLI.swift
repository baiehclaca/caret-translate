import ArgumentParser

@main struct CoreMLPipelinesCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "coremltoolkit-cli",
        abstract: "CoreMLPipelines CLI",
        discussion: "",
        subcommands: [
            TextGenerationCLI.self,
            ChatCLI.self,
            ProfileCLI.self
        ],
        defaultSubcommand: ChatCLI.self
    )
}
