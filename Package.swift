// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let name = "ListLoader"

let package = Package(
    name: name,
    products: [
        .library(
            name: name,
            targets: [name]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: name,
            dependencies: []),
        .testTarget(
            name: "ListLoaderTests",
            dependencies: ["ListLoader"]),
    ]
)
