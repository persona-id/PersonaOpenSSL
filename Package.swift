// swift-tools-version:5.3
 
import PackageDescription
 
let package = Package(
    name: "PersonaOpenSSL",
    platforms: [
        .iOS(.v9),
        .macOS(.v10_10)
    ],
    products: [
        .library(
            name: "PersonaOpenSSL",
            targets: ["PersonaOpenSSL"]),
    ],
    targets: [
        .binaryTarget(
            name: "PersonaOpenSSL",
            path: "Frameworks/PersonaOpenSSL.xcframework"
        )
    ]
)
