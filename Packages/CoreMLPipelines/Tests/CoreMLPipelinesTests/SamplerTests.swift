import CoreML
@testable import CoreMLPipelines
import Foundation
import Testing

@Test func testGreedySampler() async {
    let sampler = GreedySampler()
    let sample = await sampler.sample(MLShapedArray(scalars: [1, 4, 2, 3], shape: [4]))
    #expect(sample == 1)
}
