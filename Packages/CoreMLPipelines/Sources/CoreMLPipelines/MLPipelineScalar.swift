import Foundation

#if os(macOS)
typealias PipelineFloat = Float
#else
typealias PipelineFloat = Float16
#endif
