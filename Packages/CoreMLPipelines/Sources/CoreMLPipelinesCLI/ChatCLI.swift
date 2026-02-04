import ArgumentParser
import CoreMLPipelines
import Foundation
import Hub
import SwiftTUI

// MARK: - ChatCLI

struct ChatCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Chat using CoreMLPipelines"
    )

    @Option var model: String = TextGenerationPipeline.Model.llama_3_2_1B_Instruct_4bit.rawValue

    func run() async throws {
        ActivityIndicator.start(title: "Loading \(model.brightGreen)…")
        let pipeline = try await TextGenerationPipeline(modelName: model)
        ActivityIndicator.stop()
        CommandLine.success("Model loaded!")

        var messages: [[String: String]] = []
        while true {
            let prompt = CommandLine.askForText()
            guard prompt.localizedCaseInsensitiveCompare("exit") != .orderedSame,
                  prompt.localizedCaseInsensitiveCompare("quit") != .orderedSame else { break }
            messages.append([
                "role": "user",
                "content": prompt
            ])
            let stream = pipeline(messages: messages)
            var response = ""
            for try await text in stream {
                response += text
                print(text, terminator: "")
                fflush(stdout)
            }
            messages.append([
                "role": "assistant",
                "content": response
            ])
            print("")
        }
    }
}
