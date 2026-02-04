import ArgumentParser
import CoreMLPipelines
import Foundation
import Hub
import SwiftTUI

// MARK: - TextGenerationCLI

struct TextGenerationCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-text",
        abstract: "Generate text using CoreMLPipelines"
    )

    @Option var model: String = TextGenerationPipeline.Model.llama_3_2_1B_Instruct_4bit.rawValue
    @Argument var prompt: String = "Hello"
    @Option var maxNewTokens: Int?

    func run() async throws {
        ActivityIndicator.start(title: "Loading \(model.brightGreen)…")
        let pipeline = try await TextGenerationPipeline(modelName: model)
        ActivityIndicator.stop()
        CommandLine.success("Model loaded!")

        let stream = pipeline(
            messages: [[
                "role": "user",
                "content": prompt
            ]],
            maxNewTokens: maxNewTokens
        )
        for try await text in stream {
            print(text, terminator: "")
            fflush(stdout)
        }
        print("")
    }
}
