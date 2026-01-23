// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CaretTranslate",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "CaretTranslateCore", targets: ["CaretTranslateCore"]),
        .executable(name: "CaretTranslateApp", targets: ["CaretTranslateApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/finnvoor/CoreMLPipelines.git", branch: "main")
    ],
    targets: [
        .target(
            name: "CaretTranslateCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "CaretTranslateApp",
            dependencies: [
                "CaretTranslateCore",
                .product(name: "CoreMLPipelines", package: "CoreMLPipelines")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CaretTranslateCoreTests",
            dependencies: ["CaretTranslateCore"]
        ),
        .testTarget(
            name: "CaretTranslateAppTests",
            dependencies: ["CaretTranslateApp"]
        )
    ]
)
