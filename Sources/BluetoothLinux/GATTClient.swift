//
//  GATTClient.swift
//  BluetoothLinux
//
//  Created by Alsey Coleman Miller on 2/29/16.
//  Copyright © 2016 PureSwift. All rights reserved.
//

import Foundation
import Bluetooth

/// GATT Client
public final class GATTClient {
    
    // MARK: - Properties
    
    public var log: ((String) -> ())?
    
    public var database = GATTDatabase()
    
    // Don't modify
    @_versioned
    internal let connection: ATTConnection
    
    // MARK: - Initialization
    
    deinit {
        
        self.connection.unregisterAll()
    }
    
    public init(socket: L2CAPSocket,
                maximumTransmissionUnit: Int = ATT.MTU.LowEnergy.Default,
                log: ((String) -> ())? = nil) {
        
        self.connection = ATTConnection(socket: socket)
        self.connection.maximumTransmissionUnit = maximumTransmissionUnit
        self.log = log
        self.registerATTHandlers()
        
        // queue MTU exchange
        self.exchangeMTU()
    }
    
    // MARK: - Methods
    
    /// Performs the actual IO for recieving data.
    @inline(__always)
    public func read() throws {
        
        try connection.read()
    }
    
    /// Performs the actual IO for sending data.
    @inline(__always)
    public func write() throws -> Bool {
        
        return try connection.write()
    }
    
    // MARK: Requests
    
    /// Discover All Primary Services
    ///
    /// This sub-procedure is used by a client to discover all the primary services on a server.
    public func discoverAllPrimaryServices(completion: @escaping (GATTClientResponse<[Service]>) -> ()) {
        
        /// The Attribute Protocol Read By Group Type Request shall be used with 
        /// the Attribute Type parameter set to the UUID for «Primary Service». 
        /// The Starting Handle shall be set to 0x0001 and the Ending Handle shall be set to 0xFFFF.
        discoverServices(start: 0x0001, end: 0xFFFF, primary: true, completion: completion)
    }
    
    // MARK: - Private Methods
    
    @inline(__always)
    private func registerATTHandlers() {
        
        // value confirmation
        
    }
    
    private func send <Request: ATTProtocolDataUnit, Response: ATTProtocolDataUnit> (_ request: Request, response: @escaping (ATTResponse<Response>) -> ()) -> UInt? {
        
        log?("Request: \(request)")
        
        let callback: (AnyATTResponse) -> () = { response(ATTResponse<Response>($0)) }
        
        let responseType: ATTProtocolDataUnit.Type = Response.self
        
        return connection.send(request, response: (callback, responseType))
    }
    
    // MARK: Requests
    
    private func exchangeMTU() {
        
        let clientMTU = UInt16(self.connection.maximumTransmissionUnit)
        
        let pdu = ATTMaximumTransmissionUnitRequest(clientMTU: clientMTU)
        
        guard let _ = send(pdu, response: { [unowned self] in self.exchangeMTUResponse($0) })
            else { fatalError("Could not add PDU to request queue. Invalid state.") }
    }
    
    private func discoverServices(uuid: BluetoothUUID? = nil,
                                  start: UInt16 = 0x0001,
                                  end: UInt16 = 0xffff,
                                  primary: Bool = true,
                                  completion: @escaping (GATTClientResponse<[Service]>) -> ()) {
        
        let serviceType = GATT.UUID(primaryService: primary)
        
        let operation = DiscoverServicesOperation(uuid: uuid,
                                                  start: start,
                                                  end: end,
                                                  serviceType: serviceType,
                                                  completion: completion)
        
        let sendOperationID: UInt?
        
        if let uuid = uuid {
            
            let pdu = ATTFindByTypeRequest(startHandle: start,
                                           endHandle: end,
                                           attributeType: serviceType.rawValue,
                                           attributeValue: uuid.littleEndian)
            
            sendOperationID = send(pdu) { [unowned self] in self.findByType($0, operation: operation) }
            
        } else {
            
            
            
            let pdu = ATTReadByGroupTypeRequest(startHandle: start,
                                                endHandle: end,
                                                type: serviceType.toUUID())
            
            sendOperationID = send(pdu) { [unowned self] in self.readByGroupType($0, operation: operation) }
        }
        
        /// immediately call completion with error
        guard sendOperationID != nil else {
            completion(.error(.queueFull))
            return
        }
    }
    
    private func servicesDiscoveryComplete(operation: DiscoverServicesOperation) {
        
        
    }
    
    // MARK: - Callbacks
    
    private func exchangeMTUResponse(_ response: ATTResponse<ATTMaximumTransmissionUnitResponse>) {
        
        switch response {
            
        case let .error(error):
            
            log?("Could not exchange MTU: \(error)")
            
        case let .value(pdu):
            
            let finalMTU = Int(pdu.serverMTU)
            
            let currentMTU = self.connection.maximumTransmissionUnit
            
            log?("MTU Exchange (\(currentMTU) -> \(finalMTU))")
            
            self.connection.maximumTransmissionUnit = finalMTU
        }
    }
    
    private func readByGroupType(_ response: ATTResponse<ATTReadByGroupTypeResponse>, operation: DiscoverServicesOperation) {
        
        // Read By Group Type Response returns a list of Attribute Handle, End Group Handle, and Attribute Value tuples
        // corresponding to the services supported by the server. Each Attribute Value contained in the response is the 
        // Service UUID of a service supported by the server. The Attribute Handle is the handle for the service declaration.
        // The End Group Handle is the handle of the last attribute within the service definition. 
        // The Read By Group Type Request shall be called again with the Starting Handle set to one greater than the 
        // last End Group Handle in the Read By Group Type Response.
        
        switch response {
            
        case let .error(error):
            
            print(error)
            
        case let .value(pdu):
            
            var operation = operation
            
            operation.start += 1
            
            let lastEnd = pdu.data.last?.endGroupHandle ?? 0x00
            
            if lastEnd < operation.end {
                
                let pdu = ATTFindByTypeRequest(startHandle: operation.start,
                                               endHandle: operation.end,
                                               attributeType: operation.serviceType.rawValue,
                                               attributeValue: operation.uuid?.littleEndian ?? [])
                
                guard let _ = send(pdu, response: { [unowned self] in self.findByType($0, operation: operation) })
                    else { operation.completion(.error(.queueFull)); return }
                
                
            }
        }
        
        
    }
    
    private func findByType(_ response: ATTResponse<ATTFindByTypeResponse>, operation: DiscoverServicesOperation) {
        
        
    }
}

// MARK: - Supporting Types

public extension GATTClient {
    
    public typealias Error = GATTClientError
    
    public typealias Response<Value> = GATTClientResponse<Value>
}

public enum GATTClientError: Error {
    
    /// The request was not successfully sent because the underlying transmit queue is full.
    case queueFull
    
    /// The GATT server responded with an error response.
    case errorResponse(ATTErrorResponse)
}

public enum GATTClientResponse <Value> {
    
    case error(GATTClientError)
    case value(Value)
}

public extension GATTClient {
    
    /// A discovered service.
    public struct Service {
        
        public let uuid: BluetoothUUID
    }
}

// MARK: - Private Supporting Types

private extension GATTClient {
    
    struct DiscoverServicesOperation {
        
        let uuid: BluetoothUUID?
        
        var start: UInt16
        
        let end: UInt16
        
        let serviceType: GATT.UUID
        
        let completion: (GATTClientResponse<[Service]>) -> ()
    }
}
