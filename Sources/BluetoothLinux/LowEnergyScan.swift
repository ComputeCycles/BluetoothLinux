//
//  LowEnergyScan.swift
//  BluetoothLinux
//
//  Created by Alsey Coleman Miller on 11/28/17.
//  Copyright © 2017 PureSwift. All rights reserved.
//

#if os(Linux)
    import Glibc
    import CSwiftBluetoothLinux
#elseif os(macOS) || os(iOS)
    import Darwin.C
#endif

import Foundation
import Bluetooth

public extension Adapter {
    
    /// Scan LE devices.
    func lowEnergyScan(duration: TimeInterval = 10,
                       filterDuplicates: Bool = true,
                       parameters: LowEnergyCommand.SetScanParametersParameter = .init(),
                       commandTimeout timeout: Int = 1000,
                       shouldContinueScanning: () -> (Bool),
                       foundDevice: () -> ()) throws {
        
        // set parameters first
        try deviceRequest(parameters, timeout: timeout)
        
        // macro for enabling / disabling scan
        func enableScan(_ isEnabled: Bool = true) throws {
            
            let scanEnableCommand = LowEnergyCommand.SetScanEnableParameter(enabled: isEnabled, filterDuplicates: filterDuplicates)
            
            do { try deviceRequest(scanEnableCommand, timeout: timeout) }
            catch HCIError.commandDisallowed { /* ignore, means already turned on or off */ }
        }
        
        // enable scanning
        try enableScan()
        
        // disable scanning
        defer { do { try enableScan(false) } catch { /* ignore all errors disabling scanning */ } }
        
        // poll for scanned devices
        try PollScannedDevices(internalSocket,
                               duration: duration,
                               shouldContinueScanning: shouldContinueScanning,
                               foundDevice: foundDevice)
    }
}

/// Poll for scanned devices
internal func PollScannedDevices(_ deviceDescriptor: CInt,
                                 duration: TimeInterval,
                                 shouldContinueScanning: () -> (Bool),
                                 foundDevice: () -> ()) throws {
    
    var eventBuffer = [UInt8](repeating: 0, count: HCI.maximumEventSize)
    
    var oldFilterLength = socklen_t(MemoryLayout<HCIFilter>.size)
    var oldFilter = HCIFilter()
    
    // get old filter
    guard withUnsafeMutablePointer(to: &oldFilter, {
        let pointer = UnsafeMutableRawPointer($0)
        return getsockopt(deviceDescriptor, SOL_HCI, HCISocketOption.Filter.rawValue, pointer, &oldFilterLength) == 0
    }) else { throw POSIXError.fromErrno! }
    
    var newFilter = HCIFilter()
    newFilter.clear()
    newFilter.setPacketType(.Event)
    newFilter.setEvent(HCIGeneralEvent.LowEnergyMeta.rawValue)
    
    // set new filter
    var newFilterLength = socklen_t(MemoryLayout<HCIFilter>.size)
    guard withUnsafeMutablePointer(to: &newFilter, {
        let pointer = UnsafeMutableRawPointer($0)
        return setsockopt(deviceDescriptor, SOL_HCI, HCISocketOption.Filter.rawValue, pointer, newFilterLength) == 0
    }) else { throw POSIXError.fromErrno! }
    
    // restore old filter in case of error
    func restoreFilter(_ error: Error) -> Error {
        
        guard withUnsafeMutablePointer(to: &oldFilter, {
            let pointer = UnsafeMutableRawPointer($0)
            return setsockopt(deviceDescriptor, SOL_HCI, HCISocketOption.Filter.rawValue, pointer, newFilterLength) == 0
        }) else { return AdapterError.CouldNotRestoreFilter(error, POSIXError.fromErrno!) }
        
        return error
    }
    
    let startDate = Date()
    let endDate = startDate + duration
    
    var results = [String]()
    
    // poll until timeout
    while Date() < endDate {
        
        var actualBytesRead = 0
        
        func doRead() { actualBytesRead = read(deviceDescriptor, &eventBuffer, eventBuffer.count) }
        
        doRead()
        
        while actualBytesRead < 0 {
            
            // ignore these errors
            if (errno == EAGAIN || errno == EINTR) {
                
                // try again
                doRead()
                continue
                
            } else {
                
                // attempt to restore filter and throw
                throw restoreFilter(POSIXError.fromErrno!)
            }
        }
        
        let headerData = Array(eventBuffer[1 ..< 1 + HCIEventHeader.length])
        let eventData = Array(eventBuffer[(1 + HCIEventHeader.length) ..< actualBytesRead])
        
        guard let meta = HCIGeneralEvent.LowEnergyMeta(bytes: )
            else { return  }
    }
    
    return results
}

