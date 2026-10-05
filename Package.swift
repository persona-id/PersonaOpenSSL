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
        .library(
            name: "PersonaOpenSSLStatic",
            targets: ["PersonaOpenSSLStatic"]),
    ],
    targets: [
        .binaryTarget(
            name: "PersonaOpenSSL",
            url: "https://github.com/persona-id/PersonaOpenSSL/releases/download/3.5.8000-beta.1/PersonaOpenSSL.xcframework.zip",
            checksum: "050cd2dce118370959583d11997652526150b4c7f8dbc93ea994c2f678990bf0"
        ),
        .binaryTarget(
            name: "PersonaOpenSSLStatic",
            url: "https://github.com/persona-id/PersonaOpenSSL/releases/download/3.5.8000-beta.2/PersonaOpenSSLStatic.xcframework.zip",
            checksum: "e9691df4e44fc140ab50c7a3195f2bb876fd828b358a7997e6d81c7019a341a9"
        )
    ]
)
