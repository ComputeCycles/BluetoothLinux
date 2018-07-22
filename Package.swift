// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BluetoothLinux",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "BluetoothLinux",
            targets: ["BluetoothLinux"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
      .package(url: "https://github.com/ComputeCycles/Bluetooth.git", .branch("swift4")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "BluetoothLinux",
            dependencies: ["Bluetooth", "CSwiftBluetoothLinux"]),
        .target(
            name: "CSwiftBluetoothLinux",
            dependencies: []),
        .testTarget(
            name: "BluetoothLinuxTests",
            dependencies: ["BluetoothLinux", "CSwiftBluetoothLinuxTest"]),
        .target(
            name: "CSwiftBluetoothLinuxTest",
            dependencies: []),
    ]
)
