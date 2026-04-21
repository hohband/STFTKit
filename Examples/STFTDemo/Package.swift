// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "STFTDemo",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "STFTDemo", targets: ["STFTDemo"])
    ],
    dependencies: [
        .package(name: "STFTKit", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "STFTDemo",
            dependencies: ["STFTKit"],
            path: "."
        )
    ]
)
