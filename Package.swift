// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "JTSSloppySwiping",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .library(name: "JTSSloppySwiping", targets: ["JTSSloppySwiping"]),
    ],
    targets: [
        .target(name: "JTSSloppySwiping")
    ],
    swiftLanguageVersions: [ .v5 ]
)
