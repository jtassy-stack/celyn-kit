// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CelynKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CelynKit", targets: ["CelynKit"]),
    ],
    targets: [
        .target(
            name: "CelynKit",
            path: "Sources/CelynKit"
        ),
        .testTarget(
            name: "CelynKitTests",
            dependencies: ["CelynKit"],
            path: "Tests/CelynKitTests"
        ),
    ]
)
