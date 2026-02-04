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
            let count = multiArray.count
            let pointer = multiArray.dataPointer.bindMemory(to: UInt16.self, capacity: count)
            var floats: [Float] = []
            floats.reserveCapacity(count)
            for index in 0..<count {
                floats.append(floatFromHalf(pointer[index]))
            }
            let shape = multiArray.shape.map { $0.intValue }
            return MLShapedArray(scalars: floats, shape: shape)
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

    /// Converts IEEE 754 half-precision bits into a Float without using Float16 (unavailable on macOS).
    private func floatFromHalf(_ value: UInt16) -> Float {
        let sign = UInt32(value & 0x8000) << 16
        var exponent = Int((value & 0x7C00) >> 10)
        var mantissa = UInt32(value & 0x03FF)

        if exponent == 0 {
            if mantissa == 0 {
                return Float(bitPattern: sign)
            }
            exponent = 1
            while (mantissa & 0x0400) == 0 {
                mantissa <<= 1
                exponent -= 1
            }
            mantissa &= 0x03FF
        } else if exponent == 0x1F {
            let bits = sign | 0x7F800000 | (mantissa << 13)
            return Float(bitPattern: bits)
        }

        let exponentBits = UInt32(exponent + (127 - 15)) << 23
        let mantissaBits = mantissa << 13
        let bits = sign | exponentBits | mantissaBits
        return Float(bitPattern: bits)
    }
}
