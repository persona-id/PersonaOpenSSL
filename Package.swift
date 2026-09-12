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
            url: "https://github.com/persona-id/PersonaOpenSSL/releases/download/3.5.8000-beta.1/PersonaOpenSSL.xcframework.zip",
            checksum: "050cd2dce118370959583d11997652526150b4c7f8dbc93ea994c2f678990bf0"
        )
    ]
)
