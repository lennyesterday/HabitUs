// swift-tools-version: 5.10
// HabitCore holds every game rule from SPEC section 3.
// No SwiftUI, no Supabase, no internet. Run the tests with: swift test
import PackageDescription

let package = Package(
    name: "HabitCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HabitCore", targets: ["HabitCore"])
    ],
    targets: [
        .target(name: "HabitCore"),
        .testTarget(name: "HabitCoreTests", dependencies: ["HabitCore"])
    ]
)
