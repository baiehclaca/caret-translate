import CoreML
@testable import CoreMLPipelines
import Testing

@Test func testCausalMask() async throws {
    let causalMask = await MLTensor.causalMask(size: 5)
        .shapedArray(of: Float16.self)
    #expect(causalMask.shape == [1, 1, 5, 5])
    let x = -Float16.greatestFiniteMagnitude
    #expect(causalMask.scalars == [
        0, x, x, x, x,
        0, 0, x, x, x,
        0, 0, 0, x, x,
        0, 0, 0, 0, x,
        0, 0, 0, 0, 0,
    ])
}
