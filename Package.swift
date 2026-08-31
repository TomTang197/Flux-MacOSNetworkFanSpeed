// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AeroPulseSafety",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "AeroPulsePerformanceCore",
            path: "AeroPulse/Performance"
        ),
        .target(
            name: "FanHelperSafety",
            path: "FanPrivilegedHelper/Safety"
        ),
        .target(
            name: "AeroPulseFanSafety",
            path: "AeroPulse/Services/FanSafety"
        ),
        .testTarget(
            name: "AeroPulseSafetyTests",
            dependencies: ["FanHelperSafety", "AeroPulseFanSafety", "AeroPulsePerformanceCore"],
            path: "Tests/AeroPulseSafetyTests"
        ),
    ]
)
