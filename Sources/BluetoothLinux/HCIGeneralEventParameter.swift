//
//  HCIGeneralEventParameter.swift
//  BluetoothLinux
//
//  Created by Alsey Coleman Miller on 3/3/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

public extension HCIGeneralEvent {
    
    // TODO: Complete all command parameters
    
    public struct CommandCompleteParameter: HCIEventParameter {
        
        public static let event = HCIGeneralEvent.CommandComplete
        public static let length = 3
        
        public var ncmd: UInt8 = 0
        public var opcode: UInt16 = 0
        
        public init() { }
        
        public init?(byteValue: [UInt8]) {
            
            
        }
    }
    
    public struct CommandStatusParameter: HCIEventParameter {
        
        public static let event = HCIGeneralEvent.CommandStatus
        public static let length = 4
        
        public var status: UInt8 = 0
        public var ncmd: UInt8 = 0
        public var opcode: UInt16 = 0
        
        public init() { }
        
        public init?(byteValue: [UInt8]) {
            
            
        }
    }
    
    public struct LowEnergyMetaParameter: HCIEventParameter {
        
        public static let event = HCIGeneralEvent.LowEnergyMeta
        public static let length = 1 // Why?
        
        public var subevent: UInt8 = 0
        public var data = [Int8]()
        
        public init() { }
        
        public init?(byteValue: [UInt8]) {
            
            
        }
    }
}