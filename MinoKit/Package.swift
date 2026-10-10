// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MinoKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MinoKit", targets: ["MinoKit"])
    ],
    targets: [
        .target(name: "MinoKit"),
        .testTarget(name: "MinoKitTests", dependencies: ["MinoKit"])
    ]
)
