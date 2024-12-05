//
//  DataShapeSubscriber.swift
//  ElectricSync
//
//  Created by Paul Harter on 04/12/2024.
//

import Foundation

class ItemListPublisher<T: Comparable & Hashable & Identifiable & ElectricDecodable >: ObservableObject, ShapeSubscriber{
    
    @Published var items: [T] = []
    var data: [String: T] = [:]
    private let subId: String = NSUUID().uuidString
    private var subscription: ShapeSubscription?
    
    init(dbUrl: String = "http://localhost:3000", table: String, whereClause: String? = nil) {
        self.subscription = ShapeSubscription(subscriber: self, dbUrl: dbUrl, table: table, whereClause: whereClause)
        self.subscription!.start()
    }
    
    deinit {
        self.subscription!.pause()
    }
     
    func operations(_ dataChangeOperations: [DataChangeOperation]){
        
        var changed = false
        
        do {
            for operation in dataChangeOperations{
                if try applyOperation(operation){
                    changed = true
                }
            }
        } catch {
            //TODO ??
        }
        
        if changed {
            var values = Array(data.values)
            values.sort()
            items = values
        }
    }
    
    func subscriberId() -> String {
        return subId
    }

    func applyOperation(_ operation: DataChangeOperation) throws -> Bool {
        
        switch operation.operation{
         case "insert":
            if !data.keys.contains(operation.key){
                try data[operation.key] = T.init(from: operation.value)
                return true
            } else {
                return false
            }
         case "update":
            guard var obj = data[operation.key] else { return false }
            return try obj.update(from: operation.value)
         case "delete":
            if data.keys.contains(operation.key){
                data.removeValue(forKey: operation.key)
                return true
            }
            return false
         default:
            return false
         }
    }
}
