// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EulerCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "EulerCore", targets: ["EulerCore"])],
    targets: [
        .target(name: "EulerCore", exclude: ["CoreSources.md"]),
        .testTarget(name: "EulerCoreTests", dependencies: ["EulerCore"])
    ]
)
