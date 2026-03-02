// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        productTypes: [
            "WuhuDocView": .framework,
        ]
    )
#endif

let package = Package(
    name: "WuhuDocViewDependencies",
    dependencies: [
        .package(path: ".."),
    ]
)
