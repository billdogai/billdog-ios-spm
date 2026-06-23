// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "BillDog",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // 1. BillDog (Full Monetization + Engagement Suite)
        .library(
            name: "BillDog",
            targets: ["BillDog"]
        ),
        // 2. BillDogEng (Engagement Suite only)
        .library(
            name: "BillDogEng",
            targets: ["BillDogEng"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.4.0")
    ],
    targets: [
        // Precompiled binary targets for the closed-source SDK release
        .binaryTarget(
            name: "BillDog",
            url: "https://github.com/billdogai/billdog-ios-spm/releases/download/v1.0.0-beta.1/BillDog.xcframework.zip",
            checksum: "a462a1b8e258f719d5697deee218a46edb72a2cc2b99ccb460a3544738b74f8a"
        ),
        .binaryTarget(
            name: "BillDogEng",
            url: "https://github.com/billdogai/billdog-ios-spm/releases/download/v1.0.0-beta.1/BillDogEng.xcframework.zip",
            checksum: "a3ac4d35e0bf481841d835e8f2f781bc2175e27a5e0797d2a73875d03b576bf9"
        )
    ]
)
