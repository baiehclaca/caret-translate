import CoreML

protocol Sampler {
    func sample(_ logits: any MLShapedArrayProtocol<PipelineFloat>) async -> Int
}
