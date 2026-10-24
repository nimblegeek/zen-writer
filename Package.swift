// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZenWriter",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ZenWriter", targets: ["ZenWriter"])],
    targets: [
        .target(name: "ZenCore"),
        .executableTarget(name: "ZenWriter", dependencies: ["ZenCore"]),
        .testTarget(name: "ZenCoreTests", dependencies: ["ZenCore"])
    ],
    swiftLanguageModes: [.v5]
)
