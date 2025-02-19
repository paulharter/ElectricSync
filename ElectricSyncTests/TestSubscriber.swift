//
//  TestSubscriber.swift
//  ElectricSyncTests
//
//  Created by Paul Harter on 22/11/2024.
//

import Foundation
@testable import ElectricSync



public class TestSubscriber: ShapeSubscriber{


    public var values: [String: [String: Any]] = [:]
    public var counter: Int = 0
    
    public func update(operations: [DataChangeOperation], handle: String, offset: String) {
        
        for operation in operations{
            applyOperation(operation)
        }
        counter += 1
    }
    
    public func reset(_ handle: String) {
        
    }

    
    func applyOperation(_ operation: DataChangeOperation){
        
        switch operation.operation{
         case "insert":
            values[operation.key] = operation.value as [String: Any]
        case "update":
            for (k, v) in operation.value{
                values[operation.key]![k] = v
            }
            print("update")
        case "delete":
            values.removeValue(forKey: operation.key)
         default:
            print("unknown")
         }
    }
    
    func waitForNextUpdate(_ currentCounter: Int) async throws {
        var loolcounter: Int = 0
        while counter <= currentCounter && loolcounter < 10000{
//            print("elephant: \(counter)")
            loolcounter += 1
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
    
}
