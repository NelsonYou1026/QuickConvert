// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickConvert",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "QuickConvertCore", targets: ["QuickConvertCore"]),
        .executable(name: "quickconvert", targets: ["QuickConvertCLI"])
    ],
    targets: [
        .target(name: "QuickConvertCore"),
        .executableTarget(name: "QuickConvertCLI", dependencies: ["QuickConvertCore"]),
        .testTarget(name: "QuickConvertCoreTests", dependencies: ["QuickConvertCore"], resources: [.copy("Fixtures")])
    ]
)
