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
            checksum: "1daf44732e9a21c4f7f830122e1cdd56bff9b8343dc553acb7d92c9b74e28f7e"
        )
    ]
)
