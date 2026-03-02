// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WuhuDocView",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "WuhuDocView", targets: ["WuhuDocView"]),
    ],
    targets: [
        .target(name: "WuhuDocView"),
    ]
)
