// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "CoreMLPipelines",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CoreMLPipelines", targets: ["CoreMLPipelines"]),
        .executable(name: "coremlpipelines-cli", targets: ["CoreMLPipelinesCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/huggingface/swift-transformers.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/finnvoor/SwiftTUI.git", branch: "main")
    ],
    targets: [
        .target(
            name: "CoreMLPipelines",
            dependencies: [
                .product(name: "Transformers", package: "swift-transformers")
            ]
        ),
        .executableTarget(
            name: "CoreMLPipelinesCLI",
            dependencies: [
                "CoreMLPipelines",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftTUI", package: "SwiftTUI")
            ]
        ),
        .testTarget(name: "CoreMLPipelinesTests", dependencies: ["CoreMLPipelines"])
    ]
)
