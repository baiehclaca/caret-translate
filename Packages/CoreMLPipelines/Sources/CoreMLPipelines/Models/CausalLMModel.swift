import CoreML
@preconcurrency import Hub
import Tokenizers

class CausalLMModel {
    // MARK: Lifecycle

    /// Creates a causal language model wrapper around the provided Core ML model.
    init(model: MLModel) {
        assert(model.modelDescription.inputDescriptionsByName["input_ids"] != nil)
        assert(model.modelDescription.inputDescriptionsByName["causal_mask"] != nil)
        assert(model.modelDescription.outputDescriptionsByName["logits"] != nil)
        self.model = model
    }

    // MARK: Internal

    typealias KVCache = MLState

    /// Loads a compiled model from disk using the provided configuration.
    class func load(
        contentsOf url: URL,
        configuration: MLModelConfiguration = MLModelConfiguration()
    ) async throws -> CausalLMModel {
        try await CausalLMModel(
            model: MLModel.load(contentsOf: url, configuration: configuration)
        )
    }

    /// Loads a compiled model from the Hub by name.
    class func from(pretrained model: String, hubAPI: HubApi = .shared) async throws -> CausalLMModel {
        async let _fileNames = try hubAPI.getFilenames(from: model, matching: ["*.mlmodelc/*"])
        async let _modelURL = try hubAPI.snapshot(from: model, matching: ["*.mlmodelc/*"])
        let (fileNames, modelURL) = try await (_fileNames, _modelURL)
        return try await CausalLMModel.load(contentsOf: modelURL.appending(
            path: fileNames[0].split(separator: "/")[0]
        ))
    }

    /// Runs a forward pass and returns the logits as a shaped array.
    func forward(
        inputIDs: MLShapedArray<Int32>,
        causalMask: MLShapedArray<PipelineFloat>,
        kvCache: KVCache,
        options: MLPredictionOptions = .init()
    ) async throws -> MLShapedArray<PipelineFloat> {
        let prediction = try await model.prediction(
            from: MLDictionaryFeatureProvider(dictionary: [
                "input_ids": MLMultiArray(inputIDs),
                "causal_mask": MLMultiArray(causalMask)
            ]),
            using: kvCache,
            options: options
        )
        let logits = try logitsMultiArray(from: prediction)
        return try shapedArray(from: logits)
    }

    /// Convenience to call `forward` as a function.
    func callAsFunction(
        inputIDs: MLShapedArray<Int32>,
        causalMask: MLShapedArray<PipelineFloat>,
        kvCache: KVCache,
        options: MLPredictionOptions = .init()
    ) async throws -> MLShapedArray<PipelineFloat> {
        try await forward(
            inputIDs: inputIDs,
            causalMask: causalMask,
            kvCache: kvCache,
            options: options
        )
    }

    /// Creates an empty key/value cache for the model.
    func makeKVCache() -> KVCache {
        model.makeState()
    }

    // MARK: Private

    private enum CausalLMModelError: Error {
        case missingOutput(String)
        case invalidOutputType(String)
        case unsupportedOutputDataType(MLMultiArrayDataType)
    }

    private let model: MLModel

    /// Returns the logits MLMultiArray from a prediction, or throws if missing or invalid.
    private func logitsMultiArray(from prediction: MLFeatureProvider) throws -> MLMultiArray {
        guard let value = prediction.featureValue(for: "logits") else {
            throw CausalLMModelError.missingOutput("logits")
        }
        guard let multiArray = value.multiArrayValue else {
            throw CausalLMModelError.invalidOutputType("logits")
        }
        return multiArray
    }

    /// Converts an MLMultiArray into the pipeline's float shaped array, handling Float16 outputs.
    private func shapedArray(from multiArray: MLMultiArray) throws -> MLShapedArray<PipelineFloat> {
#if os(macOS)
        switch multiArray.dataType {
        case .float16:
            let half = try MLShapedArray<Float16>(multiArray)
            let floats = half.scalars.map(Float.init)
            return MLShapedArray(scalars: floats, shape: half.shape)
        case .float32:
            return try MLShapedArray<PipelineFloat>(multiArray)
        default:
            throw CausalLMModelError.unsupportedOutputDataType(multiArray.dataType)
        }
#else
        switch multiArray.dataType {
        case .float16:
            return try MLShapedArray<PipelineFloat>(multiArray)
        case .float32:
            let floats = try MLShapedArray<Float>(multiArray)
            let halves = floats.scalars.map(Float16.init)
            return MLShapedArray(scalars: halves, shape: floats.shape)
        default:
            throw CausalLMModelError.unsupportedOutputDataType(multiArray.dataType)
        }
#endif
    }
}
