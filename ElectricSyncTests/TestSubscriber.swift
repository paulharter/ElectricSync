//
//  TestSubscriber.swift
//  ElectricSyncTests
//
//  Created by Paul Harter on 22/11/2024.
//

import Foundation



public class TestSubscriber: ShapeSubscriber{
    
    private let subId: String = NSUUID().uuidString
    public var values: [String: [String: Any]] = [:]
    public var counter: Int = 0
    
    func operations(_ dataChangeOperations: [DataChangeOperation]){
        
        for operation in dataChangeOperations{
            applyOperation(operation)
        }
        counter += 1
    }
    
    func subscriberId() -> String{
        return subId
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
