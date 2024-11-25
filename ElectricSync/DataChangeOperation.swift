//
//  Operation.swift
//  ElectricSync
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation


var OperationNames : Set = ["insert", "update", "delete"]


public class DataChangeOperation: NSObject{
    
    public let table: String
    public let key: String
    public let operation: String
    public let value: [String: Any]
    
    init(table: String, operation: String, key: String, value: [String: Any]) {
        self.table = table
        self.key = key
        self.value = value
        self.operation = operation
        super.init()
    }
    
    convenience init?(table: String, message: [String: Any]){

        guard let headers = message["headers"] as? [String: Any],
              let operation = headers["operation"] as? String,
              let value = message["value"] as? [String: Any],
              let key = message["key"] as? String else { return nil }

        let cleanKey = key.replacingOccurrences(of: "\"", with: "").split(separator: "/").last!
        
        if !OperationNames.contains(operation) { return nil }
        
        self.init(table: table, operation: operation, key: String(cleanKey), value: value)
        
    }
}
    
    
