// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CrossTerminal",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // 所有 Swift 源文件放在 Sources/ 下，由 SwiftPM 直接编译为可执行文件
        .executableTarget(name: "CrossTerminal", path: "Sources")
    ]
)
