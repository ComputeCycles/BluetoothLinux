//
//  main.swift
//  BluetoothLinux
//
//  Created by Alsey Coleman Miller on 12/6/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import BluetoothLinux
import Foundation

func Error(_ text: String) -> Never {
    
    print(text)
    exit(1)
}

// get Bluetooth device

guard let adapter = try? Adapter()
    else { Error("No Bluetooth adapters found") }

print("Found Bluetooth adapter with device ID: \(adapter.identifier)")

print("Address: \(adapter.address!)")

/// Perform Test
iBeaconTest(adapter: adapter, timeout: 25)

