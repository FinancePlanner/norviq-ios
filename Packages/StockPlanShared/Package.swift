// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StockPlanShared",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "StockPlanShared",
            targets: ["StockPlanShared"]
        ),
    ],
    targets: [
        .target(
            name: "StockPlanShared"
        ),
        .testTarget(
            name: "StockPlanSharedTests",
            dependencies: ["StockPlanShared"]
        ),
    ]
)
