// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CuePilot",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "CueGeometry", targets: ["CueGeometry"]),
        .library(name: "CuePhysics", targets: ["CuePhysics"]),
        .library(name: "CueStrategy", targets: ["CueStrategy"]),
        .library(name: "CueCalibration", targets: ["CueCalibration"]),
        .library(name: "CueSession", targets: ["CueSession"]),
        .library(name: "CuePresentation", targets: ["CuePresentation"]),
        .library(name: "CueDiagnostics", targets: ["CueDiagnostics"]),
        .library(name: "CueVision", targets: ["CueVision"]),
        .library(name: "CueTestSupport", targets: ["CueTestSupport"]),
        .executable(name: "CuePilotMac", targets: ["CuePilotMac"]),
    ],
    targets: [
        .target(name: "CueGeometry"),
        .target(
            name: "CuePhysics",
            dependencies: ["CueGeometry"]
        ),
        .target(
            name: "CueStrategy",
            dependencies: ["CueGeometry", "CuePhysics"]
        ),
        .target(name: "CueCalibration"),
        .target(
            name: "CueSession",
            dependencies: ["CueGeometry", "CueStrategy", "CueCalibration"]
        ),
        .target(
            name: "CuePresentation",
            dependencies: ["CueGeometry", "CueStrategy"]
        ),
        .target(name: "CueDiagnostics"),
        .target(
            name: "CueVision",
            dependencies: ["CueGeometry", "CueDiagnostics"]
        ),
        .target(
            name: "CueTestSupport",
            dependencies: ["CueGeometry", "CueVision"]
        ),
        .executableTarget(
            name: "CuePilotMac",
            dependencies: [
                "CueGeometry",
                "CuePhysics",
                "CueStrategy",
                "CueCalibration",
                "CueSession",
                "CuePresentation",
                "CueDiagnostics",
                "CueVision",
            ],
            path: "Apps/macOS/CuePilotMac",
            exclude: [
                "CuePilotMac.entitlements",
                "Info.plist",
                "PrivacyInfo.xcprivacy",
            ]
        ),
        .testTarget(
            name: "CueGeometryTests",
            dependencies: ["CueGeometry", "CuePhysics", "CueTestSupport"]
        ),
        .testTarget(
            name: "CueStrategyTests",
            dependencies: ["CueGeometry", "CuePhysics", "CueStrategy", "CueTestSupport"]
        ),
        .testTarget(
            name: "CueVisionTests",
            dependencies: ["CueGeometry", "CueVision", "CueTestSupport"]
        ),
        .testTarget(
            name: "CueSessionTests",
            dependencies: [
                "CueGeometry",
                "CueStrategy",
                "CueCalibration",
                "CueSession",
                "CuePresentation",
                "CueDiagnostics",
            ]
        ),
    ]
)
