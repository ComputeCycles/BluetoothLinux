//
//  main.swift
//  BluetoothLinux
//
//  Created by Alsey Coleman Miller on 12/6/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

#if os(Linux)
    import BluetoothLinux
    import Glibc
#elseif os(OSX) || os(iOS)
    import Darwin.C
#endif

import Foundation

func Error(_ text: String) -> Never {
    
    print(text)
    exit(1)
}

// get Bluetooth device

let adapter: Adapter

do { adapter = try Adapter() }
    
catch { Error("Error: \(error)") }

print("Found Bluetooth adapter with device ID: \(adapter.identifier)")

print("Address: \(adapter.address!)")

guard let peerAddressString = CommandLine.arguments.first
    else { Error("No Address specified") }

guard let peerAddress = Address(rawValue: peerAddressString)
    else { Error("Invalid Address specified") }

/// Perform Test
LECreateConnection(adapter: adapter, peerAddress: peerAddress)

