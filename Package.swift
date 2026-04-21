// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "STFTKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "STFTKit", targets: ["STFTKit"])
    ],
    targets: [
        .target(name: "STFTKit", dependencies: [])
    ]
)
