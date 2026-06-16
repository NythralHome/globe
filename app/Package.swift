// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Globe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Globe", targets: ["GlobeApp"]),
        .library(name: "GlobeCore", targets: ["GlobeCore"])
    ],
    targets: [
        .target(
            name: "GlobeCore",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "GlobeApp",
            dependencies: ["GlobeCore"]
        ),
        .testTarget(
            name: "GlobeCoreTests",
            dependencies: ["GlobeCore"]
        )
    ]
)
