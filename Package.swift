// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DuoFold", platforms: [.macOS(.v14)], products: [.executable(name: "DuoFold", targets: ["DuoFold"])], targets: [
 .target(name: "FoldCore"),
 .executableTarget(name: "DuoFold", dependencies: ["FoldCore"], resources: [.copy("Resources/Fold.metal")], linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ScreenCaptureKit"), .linkedFramework("MetalKit"), .linkedFramework("IOKit")]),
 .testTarget(name: "FoldCoreTests", dependencies: ["FoldCore"])
])
