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
            url: "https://github.com/billdogai/billdog-ios-spm/releases/download/v1.0.0-beta.2/BillDog.xcframework.zip",
            checksum: "0d020cb6630fa75ed45e17ac5bc23faf5527ee44d3040343baa3becf9aab4d5b"
        ),
        .binaryTarget(
            name: "BillDogEng",
            url: "https://github.com/billdogai/billdog-ios-spm/releases/download/v1.0.0-beta.2/BillDogEng.xcframework.zip",
            checksum: "963609762f475308b5bc1eea3ee1d89d6a6c8f5e5f36ff4b3ef1df13664f9d23"
        )
    ]
)
