// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swiftui-blanket",
  platforms: [
    .iOS(.v18)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "SwiftUIBlanket",
      targets: ["SwiftUIBlanket"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/FluidGroup/swift-rubber-banding", from: "1.0.0"),
    .package(
      url: "https://github.com/FluidGroup/swiftui-scrollview-interoperable-drag-gesture",
      from: "0.4.0"
    ),
    .package(url: "https://github.com/FluidGroup/swift-with-prerender", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "SwiftUIBlanket",
      dependencies: [
        .product(name: "RubberBanding", package: "swift-rubber-banding"),
        .product(name: "WithPrerender", package: "swift-with-prerender"),
        .product(name: "SwiftUIScrollViewInteroperableDragGesture", package: "swiftui-scrollview-interoperable-drag-gesture"),
      ]
    ),
    .testTarget(
      name: "SwiftUIBlanketTests",
      dependencies: ["SwiftUIBlanket"]
    ),
  ]
)
