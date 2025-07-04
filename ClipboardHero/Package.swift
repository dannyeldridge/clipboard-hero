// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClipboardHero",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipboardHero", targets: ["ClipboardHero"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardHero",
            path: "Sources"
        )
    ]
)