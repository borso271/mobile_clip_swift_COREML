// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift_tests_clip",
    platforms: [.macOS(.v13)],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "swift_tests_clip",
            resources: [
                .copy("models/"),
                .copy("images/"),
                .copy("labels.txt"),
                .copy("CLIP/labels_embeds.json")
            ]),
    ]
)
