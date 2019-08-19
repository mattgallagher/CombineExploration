// swift-tools-version:5.1

import PackageDescription

let package = Package(
	name: "CombineExploration",
	platforms: [.macOS(.v10_15)],
	products: [
		.library(
			name: "CombineExploration",
			targets: ["CombineExploration"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/ReactiveX/RxSwift.git", .exact(Version("5.0.1"))),
		.package(url: "https://github.com/mattgallagher/CwlSignal.git", .exact(Version("3.0.0-beta.1"))),
		.package(url: "https://github.com/mattgallagher/CwlUtils.git", .exact(Version("3.0.0-beta.1"))),
	],
	targets: [
		.target(
			name: "CombineExploration",
			dependencies: []),
		.testTarget(
			name: "CombineExplorationTests",
			dependencies: ["CombineExploration", "RxSwift", "CwlSignal", "CwlUtils"]),
	]
)
