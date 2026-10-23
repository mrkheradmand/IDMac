// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IDMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "IDMac",
            targets: ["IDMac"]
        )
    ],
    targets: [
        .executableTarget(
            name: "IDMac",
            path: "Sources"
        )
    ]
)
