// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "InputBridge",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "InputBridgeCore", targets: ["InputBridgeCore"]),
        .library(name: "InputBridgeHID", targets: ["InputBridgeHID"]),
        .library(name: "InputBridgeMac", targets: ["InputBridgeMac"]),
        .executable(name: "InputBridgeApp", targets: ["InputBridgeApp"])
    ],
    targets: [
        .target(
            name: "InputBridgeCore"
        ),
        .target(
            name: "InputBridgeHID",
            dependencies: ["InputBridgeCore"],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .target(
            name: "InputBridgeMac",
            dependencies: ["InputBridgeCore", "InputBridgeHID"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .executableTarget(
            name: "InputBridgeApp",
            dependencies: ["InputBridgeCore", "InputBridgeHID", "InputBridgeMac"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "InputBridgeCoreTests",
            dependencies: ["InputBridgeCore"]
        )
    ]
)
