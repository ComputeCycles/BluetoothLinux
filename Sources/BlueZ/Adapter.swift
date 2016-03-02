//
//  Adapter.swift
//  BlueZ
//
//  Created by Alsey Coleman Miller on 12/6/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

#if os(Linux)
    import Glibc
    import CSwiftBluetoothLinux
#elseif os(OSX) || os(iOS)
    import Darwin.C
#endif

import SwiftFoundation

/// Manages connection / communication to the underlying Bluetooth hardware.
public final class Adapter {

    // MARK: - Properties

    /// The device identifier of the Bluetooth adapter.
    public let identifier: CInt

    // MARK: - Internal Properties

    internal let internalSocket: CInt

    // MARK: - Initizalization

    deinit {

        close(internalSocket)
    }

    /// Initializes the Bluetooth Adapter with the specified address.
    ///
    /// If no address is specified then it tries to intialize the first Bluetooth adapter.
    public convenience init(address: Address? = nil) throws {
        
        guard let deviceIdentifier = try HCIGetRoute(address)
            else { throw BlueZError.AdapterNotFound }
        
        let internalSocket = try HCIOpenDevice(deviceIdentifier)
        
        self.init(identifier: deviceIdentifier, internalSocket: internalSocket)
    }
    
    private init(identifier: CInt, internalSocket: CInt) {
        
        self.identifier = identifier
        self.internalSocket = internalSocket
    }
}

// MARK: - Internal HCI Functions

/// int hci_open_dev(int dev_id)
internal func HCIOpenDevice(deviceIdentifier: CInt) throws -> CInt {
    
    // Create HCI socket
    let hciSocket = socket(AF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BluetoothProtocol.HCI.rawValue)
    
    guard hciSocket >= 0 else { throw POSIXError.fromErrorNumber! }
    
    // Bind socket to the HCI device
    var address = HCISocketAddress()
    address.family = sa_family_t(AF_BLUETOOTH)
    address.deviceIdentifier = UInt16(deviceIdentifier)
    
    let addressPointer = withUnsafeMutablePointer(&address) { UnsafeMutablePointer<sockaddr>($0) }
    
    guard bind(hciSocket, addressPointer, socklen_t(sizeof(HCISocketAddress))) >= 0
        else { close(hciSocket); throw POSIXError.fromErrorNumber! }
    
    return hciSocket
}

/// int hci_for_each_dev(int flag, int (*func)(int dd, int dev_id, long arg)
internal func HCIIdentifierOfDevice(flagFilter: HCIDeviceFlag = HCIDeviceFlag(), _ predicate: (deviceDescriptor: CInt, deviceIdentifier: CInt) throws -> Bool) throws -> CInt? {

    // open HCI socket

    let hciSocket = socket(AF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BluetoothProtocol.HCI.rawValue)

    guard hciSocket >= 0 else { throw POSIXError.fromErrorNumber! }

    defer { close(hciSocket) }

    // allocate HCI device list buffer

    var deviceList = HCIDeviceListRequest()

    deviceList.count = UInt16(HCI.MaximumDeviceCount)
    
    let voidDeviceListPointer = withUnsafeMutablePointer(&deviceList) { UnsafeMutablePointer<Void>($0) }
    
    // request device list
        
    let ioctlValue = swift_bluetooth_ioctl(hciSocket, HCI.IOCTL.GetDeviceList, voidDeviceListPointer)
    
    guard ioctlValue >= 0 else { throw POSIXError.fromErrorNumber! }
    
    for i in 0 ..< Int(deviceList.count) {

        let deviceRequest = deviceList[i]

        guard HCITestBit(flagFilter.rawValue, options: deviceRequest.options) else { continue }

        let deviceIdentifier = CInt(deviceRequest.identifier)
        
        /* Operation not supported by device */
        guard deviceIdentifier >= 0 else { throw POSIXError(rawValue: ENODEV)! }

        if try predicate(deviceDescriptor: hciSocket, deviceIdentifier: deviceIdentifier) {

            return deviceIdentifier
        }
    }

    return nil
}

internal func HCIGetRoute(address: Address? = nil) throws -> CInt? {

    return try HCIIdentifierOfDevice { (dd, deviceIdentifier) in

        guard let address = address else { return true }

        var deviceInfo = HCIDeviceInformation()

        deviceInfo.identifier = UInt16(deviceIdentifier)

        guard withUnsafeMutablePointer(&deviceInfo, { swift_bluetooth_ioctl(dd, HCI.IOCTL.GetDeviceInfo, UnsafeMutablePointer<Void>($0)) }) == 0 else { throw POSIXError.fromErrorNumber! }

        return deviceInfo.address == address
    }
}

/// int hci_devinfo(int dev_id, struct hci_dev_info *di)
internal func HCIDeviceInfo(deviceIdentifier: CInt) throws {
    
    // open HCI socket
    
    let hciSocket = socket(AF_BLUETOOTH, SOCK_RAW | SOCK_CLOEXEC, BluetoothProtocol.HCI.rawValue)
    
    guard hciSocket >= 0 else { throw POSIXError.fromErrorNumber! }
    
    defer { close(hciSocket) }
    
    var deviceInfo = HCIDeviceInformation()
    
    
}

@inline (__always)
internal func HCITestBit(flag: CInt, options: UInt32) -> Bool {

    return (options + (UInt32(bitPattern: flag) >> 5)) & (1 << (UInt32(bitPattern: flag) & 31)) != 0
}

// MARK: - Linux Support

#if os(Linux)

    let SOCK_RAW = CInt(Glibc.SOCK_RAW.rawValue)

    let SOCK_CLOEXEC = CInt(Glibc.SOCK_CLOEXEC.rawValue)
    
    typealias sa_family_t = Glibc.sa_family_t

#endif

// MARK: - Darwin Stubs

#if os(OSX) || os(iOS)

    var SOCK_CLOEXEC: CInt { stub() }
    
#endif
