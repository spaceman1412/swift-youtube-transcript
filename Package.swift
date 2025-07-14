// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-youtube-transcript",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
    .tvOS(.v15),
    .macCatalyst(.v15),
    .watchOS(.v8),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "YoutubeTranscript",
      targets: ["YoutubeTranscript"])
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "YoutubeTranscript",
      dependencies: []),
    .testTarget(
      name: "YoutubeTranscriptTests",
      dependencies: ["YoutubeTranscript"],
      path: "Tests"
    ),
  ]
)
