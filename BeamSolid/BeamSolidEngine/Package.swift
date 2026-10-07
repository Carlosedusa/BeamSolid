// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BeamSolidEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "BeamSolidEngine", targets: ["BeamSolidEngine"]),
    ],
    targets: [
        .target(name: "BeamSolidEngine"),
        .testTarget(name: "BeamSolidEngineTests", dependencies: ["BeamSolidEngine"]),
    ]
)
