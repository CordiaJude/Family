// swift-tools-version: 6.2
import PackageDescription

// FamilyCore depends only on Foundation so its logic and tests also build on
// Linux. The SwiftUI/SwiftData modules are Apple-platform only.
#if os(Linux)
let products: [Product] = [
    .library(name: "FamilyCore", targets: ["FamilyCore"]),
]
let targets: [Target] = [
    .target(name: "FamilyCore"),
    .testTarget(name: "FamilyCoreTests", dependencies: ["FamilyCore"]),
]
#else
let products: [Product] = [
    .library(name: "FamilyCore", targets: ["FamilyCore"]),
    .library(name: "FamilyData", targets: ["FamilyData"]),
    .library(name: "FamilyDesign", targets: ["FamilyDesign"]),
]
let targets: [Target] = [
    .target(name: "FamilyCore"),
    .target(name: "FamilyData", dependencies: ["FamilyCore"]),
    .target(name: "FamilyDesign", dependencies: ["FamilyCore", "FamilyData"]),
    .testTarget(name: "FamilyCoreTests", dependencies: ["FamilyCore"]),
    .testTarget(name: "FamilyDataTests", dependencies: ["FamilyData"]),
]
#endif

let package = Package(
    name: "FamilyKit",
    defaultLocalization: "en",
    platforms: [.iOS("26.0")],
    products: products,
    targets: targets
)
