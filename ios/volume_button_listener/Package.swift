// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "volume_button_listener",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "volume-button-listener", targets: ["volume_button_listener"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/Navideck/VolumeButtonKit.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "volume_button_listener",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "VolumeButtonKit", package: "VolumeButtonKit"),
            ]
        ),
    ]
)
