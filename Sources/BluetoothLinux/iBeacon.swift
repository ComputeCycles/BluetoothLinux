//
//  iBeacon.swift
//  BluetoothLinux
//
//  Created by Alsey Coleman Miller on 1/2/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

#if os(Linux)
    import Glibc
#elseif os(OSX) || os(iOS)
    import Darwin.C
#endif

import Foundation
import Bluetooth

public extension Adapter {
    
    /// Enable iBeacon functionality.
    func enableBeacon(uuid: Foundation.UUID = UUID(), major: UInt16, minor: UInt16, RSSI: Int8, interval: UInt16 = 100, commandTimeout: Int = 1000) throws {
                
        // set advertising parameters
        let advertisingParameters = LowEnergyCommand.SetAdvertisingParametersParameter(interval: (interval, interval))
        
        //print("Setting Advertising Parameters")
        
        try deviceRequest(advertisingParameters, timeout: commandTimeout)
        
        //print("Enabling Advertising")
        
        // start advertising
        do { try enableLowEnergyAdvertising(timeout: commandTimeout) }
        catch HCIError.commandDisallowed { /* ignore, means already turned on */ }
        
        //print("Setting iBeacon Data")
        
        // set iBeacon data
        var advertisingDataCommand = LowEnergyCommand.SetAdvertisingDataParameter()
        SetBeaconData(uuid: uuid, major: major, minor: minor, RSSI: UInt8(bitPattern: RSSI), parameter: &advertisingDataCommand)
        
        try deviceRequest(advertisingDataCommand, timeout: commandTimeout)
    }
    
    func enableLowEnergyAdvertising(_ enabled: Bool = true, timeout: Int = 1000) throws {
        
        let parameter = LowEnergyCommand.SetAdvertiseEnableParameter(enabled: enabled)
        
        try deviceRequest(parameter, timeout: timeout)
    }
}

// MARK: - Private

internal func SetBeaconData(uuid: Foundation.UUID, major: UInt16, minor: UInt16, RSSI: UInt8, parameter: inout LowEnergyCommand.SetAdvertisingDataParameter) {
    
    parameter.length = 30
    
    parameter.data.0 = 0x02  // length of flags
    parameter.data.1 = 0x01  // flags type
    parameter.data.2 = 0x1a  // Flags: 000011010
    parameter.data.3 = 0x1a  // length
    parameter.data.4 = 0xff  // vendor specific
    parameter.data.5 = 0x4c  // Apple, Inc
    parameter.data.6 = 0x00  // Apple, Inc
    parameter.data.7 = 0x02  // iBeacon
    parameter.data.8 = 0x15  // length: 21 = 16 byte UUID + 2 bytes major + 2 bytes minor + 1 byte RSSI
    
    // set UUID bytes
    
    let littleUUIDBytes = BluetoothUUID.bit128(uuid).littleEndian
    
    parameter.data.9 = littleUUIDBytes[0]
    parameter.data.10 = littleUUIDBytes[1]
    parameter.data.11 = littleUUIDBytes[2]
    parameter.data.12 = littleUUIDBytes[3]
    parameter.data.13 = littleUUIDBytes[4]
    parameter.data.14 = littleUUIDBytes[5]
    parameter.data.15 = littleUUIDBytes[6]
    parameter.data.16 = littleUUIDBytes[7]
    parameter.data.17 = littleUUIDBytes[8]
    parameter.data.18 = littleUUIDBytes[9]
    parameter.data.19 = littleUUIDBytes[10]
    parameter.data.20 = littleUUIDBytes[11]
    parameter.data.21 = littleUUIDBytes[12]
    parameter.data.22 = littleUUIDBytes[13]
    parameter.data.23 = littleUUIDBytes[14]
    parameter.data.24 = littleUUIDBytes[15]
    
    let majorBytes = major.bytes
    
    parameter.data.25 = majorBytes.1
    parameter.data.26 = majorBytes.0
    
    let minorBytes = minor.bytes
    
    parameter.data.27 = minorBytes.1
    parameter.data.28 = minorBytes.0
    
    parameter.data.29 = RSSI
}

