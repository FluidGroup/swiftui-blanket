// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swiftui-blanket",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v16),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "SwiftUIBlanket",
      targets: ["SwiftUIBlanket"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/FluidGroup/swiftui-support", from: "0.9.0"),
    .package(url: "https://github.com/FluidGroup/swift-rubber-banding", from: "1.0.0"),
    .package(
      url: "https://github.com/FluidGroup/swiftui-scrollview-interoperable-drag-gesture",
      from: "0.2.0"
    ),
    .package(url: "https://github.com/FluidGroup/swift-with-prerender", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "SwiftUIBlanket",
      dependencies: [
        .product(name: "RubberBanding", package: "swift-rubber-banding"),
        .product(name: "WithPrerender", package: "swift-with-prerender"),
        .product(name: "SwiftUISupportSizing", package: "swiftui-support"),
        .product(name: "SwiftUISupportDescribing", package: "swiftui-support"),
        .product(name: "SwiftUISupportBackport", package: "swiftui-support"),
        .product(name: "SwiftUISupportGeometryEffect", package: "swiftui-support"),
        .product(name: "SwiftUIScrollViewInteroperableDragGesture", package: "swiftui-scrollview-interoperable-drag-gesture"),
      ]
    ),
    .testTarget(
      name: "SwiftUIBlanketTests",
      dependencies: ["SwiftUIBlanket"]
    ),
  ]
)
