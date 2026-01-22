import CaretTranslateCore
import CoreMLPipelines
import Foundation

actor QwenContextualFixer: ContextualFixer {
    private let promptBuilder = ContextualFixerPrompt()
    private let modelName: String
    private let maxNewTokens: Int
    private var pipeline: TextGenerationPipeline?

    init(
        modelName: String = "finnvoorhees/coreml-Qwen2.5-0.5B-Instruct-4bit",
        maxNewTokens: Int = 128
    ) {
        self.modelName = modelName
        self.maxNewTokens = maxNewTokens
    }

    func fix(_ context: ContextualFixerContext) async throws -> String? {
        guard let prompt = promptBuilder.buildPrompt(context: context) else {
            return nil
        }

        let pipeline = try await loadPipeline()
        let stream = pipeline(messages: [[
            "role": "user",
            "content": prompt
        ]], maxNewTokens: maxNewTokens)

        var output = ""
        for try await chunk in stream {
            output.append(chunk)
            if output.contains("}") {
                break
            }
        }

        return parseResponse(output)
    }

    private func loadPipeline() async throws -> TextGenerationPipeline {
        if let pipeline {
            return pipeline
        }
        let pipeline = try await TextGenerationPipeline(modelName: modelName)
        self.pipeline = pipeline
        return pipeline
    }

    private func parseResponse(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let response = decodeResponse(trimmed) {
            return response.corrected_sentence.isEmpty ? nil : response.corrected_sentence
        }
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}") else {
            return nil
        }
        let json = String(trimmed[start...end])
        return decodeResponse(json)?.corrected_sentence
    }

    private func decodeResponse(_ json: String) -> FixerResponse? {
        guard let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(FixerResponse.self, from: data)
    }
}

private struct FixerResponse: Decodable {
    let corrected_sentence: String
    let replacement: String?
    let changed: Bool?
}
