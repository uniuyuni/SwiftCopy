// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftCopy",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "SwiftCopy", targets: ["SwiftCopy"]),
    ],
    targets: [
        .executableTarget(
            name: "SwiftCopy",
            path: "SwiftCopy",
            exclude: ["Info.plist"] // Exclude Info.plist if it exists, or just point to sources
        ),
        .testTarget(
            name: "SwiftCopyTests",
            dependencies: ["SwiftCopy"],
            path: "Tests"
        ),
    ]
)
