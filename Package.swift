// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftViewlets",
	platforms: [
		.macOS(.v14),
		.iOS(.v17),
		.macCatalyst(.v17),
		.watchOS(.v10),
		.visionOS(.v1),
	],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftViewlets",
            targets: ["SwiftViewlets"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kevinbhayes/swiftlets.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftViewlets",
            dependencies: [
                .product(name: "Swiftlets", package: "swiftlets")
            ]),
        .testTarget(
            name: "SwiftViewletsTests",
            dependencies: [
                "SwiftViewlets"
            ]
        ),
    ]
)
