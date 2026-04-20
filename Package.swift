// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TodoMenu",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TodoDomain", targets: ["TodoDomain"]),
        .executable(name: "TodoMenuApp", targets: ["TodoMenuApp"])
    ],
    targets: [
        .target(
            name: "TodoDomain"
        ),
        .executableTarget(
            name: "TodoMenuApp",
            dependencies: ["TodoDomain"],
            path: "Sources/TodoMenuApp"
        ),
        .testTarget(
            name: "TodoDomainTests",
            dependencies: ["TodoDomain"],
            resources: [
                .process("Fixtures")
            ]
        ),
        .testTarget(
            name: "TodoMenuAppTests",
            dependencies: ["TodoMenuApp"],
            path: "Tests/TodoMenuAppTests",
            resources: [
                .process("Fixtures"),
                .copy("ManualAcceptanceChecklist.md")
            ]
        )
    ]
)
