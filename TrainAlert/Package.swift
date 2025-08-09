// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TrainAlert",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TrainAlert",
            targets: ["TrainAlert"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "TrainAlert",
            dependencies: [],
            path: ".",
            exclude: [
                "TrainAlertTests",
                "TrainAlertUITests",
                "Preview Content",
                "docs",
                "README.md",
                "TestingSummary.md",
                "IntegrationTests.xctestplan",
                "PerformanceTests.xctestplan",
                "TrainAlert.xctestplan",
                "UITests.xctestplan",
                "UnitTests.xctestplan",
                "TrainAlert.xcodeproj",
                "TrainAlert.xcworkspace",
                "Package.swift"
            ],
            sources: [
                "CoreData",
                "DesignSystem",
                "Models",
                "Services",
                "Utilities",
                "ViewModels",
                "Views"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TrainAlertTests",
            dependencies: ["TrainAlert"],
            path: "TrainAlertTests"
        ),
        .testTarget(
            name: "TrainAlertUITests",
            dependencies: ["TrainAlert"],
            path: "TrainAlertUITests"
        )
    ]
)
