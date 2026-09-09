// swift-tools-version:5.3
 
import PackageDescription
 
let package = Package(
    name: "PersonaOpenSSL",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PersonaOpenSSL",
            targets: ["PersonaOpenSSL"]),
    ],
    targets: [
        .binaryTarget(
            name: "PersonaOpenSSL",
            url: "https://github.com/persona-id/PersonaOpenSSL/releases/download/3.5.8000/PersonaOpenSSL.xcframework.zip",
            checksum: "ba0607be0605fc1a4bab2c072a850030f69ece3604e2c8f82a6227ddd94d7acd"
        )
    ]
)
