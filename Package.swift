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
            checksum: "0809745686081006a68f0c0e7e89da333f86170fd807257ed790927814bd8b78"
        )
    ]
)
