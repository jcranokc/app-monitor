// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AppMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppMonitorCore", targets: ["AppMonitorCore"]),
        .executable(name: "AppMonitor", targets: ["AppMonitor"]),
        .executable(name: "AppMonitorAskpass", targets: ["AppMonitorAskpass"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            pkgConfig: "sqlite3"
        ),
        .target(
            name: "AppMonitorCore",
            dependencies: ["CSQLite"]
        ),
        .executableTarget(
            name: "AppMonitor",
            dependencies: ["AppMonitorCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "AppMonitorAskpass"
        ),
        .testTarget(
            name: "AppMonitorCoreTests",
            dependencies: ["AppMonitorCore"]
        )
    ]
)
