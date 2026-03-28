// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Molly",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Molly", targets: ["Molly"]),
    ],
    targets: [
        .executableTarget(
            name: "Molly",
            path: "Sources/Molly"
        ),
    ]
)
