import CaretTranslateCore
import CoreML
import Foundation

final class CoreMLContextualFixer: ContextualFixer {
    private let model: MLModel
    private let promptBuilder = ContextualFixerPrompt()
    private let promptFeatureName: String
    private let responseFeatureName: String?

    init?(
        modelURL: URL?,
        promptFeatureName: String = "prompt",
        responseFeatureName: String? = "text"
    ) {
        guard let modelURL else {
            return nil
        }
        do {
            self.model = try MLModel(contentsOf: modelURL)
        } catch {
            return nil
        }
        self.promptFeatureName = promptFeatureName
        self.responseFeatureName = responseFeatureName
    }

    func fix(_ context: ContextualFixerContext) async throws -> String? {
        guard let prompt = promptBuilder.buildPrompt(context: context) else {
            return nil
        }
        guard let responseText = try generate(prompt: prompt) else {
            return nil
        }
        return parseResponse(responseText)
    }

    private func generate(prompt: String) throws -> String? {
        let input = try MLDictionaryFeatureProvider(dictionary: [promptFeatureName: prompt])
        let prediction = try model.prediction(from: input)
        if let responseFeatureName,
           let value = prediction.featureValue(for: responseFeatureName)?.stringValue {
            return value
        }
        for name in prediction.featureNames {
            if let value = prediction.featureValue(for: name)?.stringValue {
                return value
            }
        }
        return nil
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
