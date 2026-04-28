// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Shangy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Shangy",
            path: "Sources/Shangy",
            exclude: ["Resources/Info.plist"],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
