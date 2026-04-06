// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "MacPulse",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MacPulse",
            targets: ["MacPulse"]
        ),
    ],
    targets: [
        .target(
            name: "MacPulseBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "MacPulse",
            dependencies: ["MacPulseBridge"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
