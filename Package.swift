// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "PersonaOpenSSL",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PersonaOpenSSLStatic",
            targets: ["PersonaOpenSSLStatic"]),
    ],
    targets: [
        .binaryTarget(
            name: "PersonaOpenSSLStatic",
            url: "https://github.com/persona-id/PersonaOpenSSL/releases/download/3.5.8000/PersonaOpenSSLStatic.xcframework.zip",
            checksum: "e9691df4e44fc140ab50c7a3195f2bb876fd828b358a7997e6d81c7019a341a9"
        )
    ]
)
