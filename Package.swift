// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "idi",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "idi", targets: ["idi"])
    ],
    targets: [
        .executableTarget(name: "idi"),
        .testTarget(name: "idiTests", dependencies: ["idi"])
    ]
)
