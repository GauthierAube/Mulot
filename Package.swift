// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mulot",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Mulot", path: "Sources/Mulot")
    ]
)
