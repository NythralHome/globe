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
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "GlobeApp",
            dependencies: ["GlobeCore"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "GlobeCoreTests",
            dependencies: ["GlobeCore"]
        )
    ]
)
