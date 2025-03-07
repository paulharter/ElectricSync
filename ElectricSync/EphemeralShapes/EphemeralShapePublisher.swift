//
//  EphemeralShapePublisher.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/03/2025.
//

import Foundation
import Combine

public class EphemeralShapePublisher<T: ElectricModel >: ObservableObject, ShapeStreamSubscriber{

    @Published public var items: [T] = []
    @Published public var error: Error?
    var data: [String: T] = [:]
    private let subId: String = NSUUID().uuidString
    private var shapeStream: ShapeStream?
    private var handle: String = ""
    private var sort: ((T, T) throws -> Bool)?
    
    init(session: URLSession, dbUrl: String, table: String, whereClause: String? = nil, sort: ((T, T) throws -> Bool)? = nil) {
        self.shapeStream = ShapeStream(session: session,
                                       subscriber: self,
                                       dbUrl: dbUrl,
                                       table: table,
                                       whereClause: whereClause)
        self.sort = sort
    }
    
    deinit {
        self.shapeStream!.pause()
    }
    
    func start(){
        self.shapeStream!.start()
    }
    
    func pause() {
        self.shapeStream!.pause()
    }
    
    func getHandle() -> String {
        return self.handle
    }
     
    func update(operations: [DataChangeOperation], handle: String, offset: String) {
        
        var changed = false
        self.handle = handle
        
        do {
            for operation in operations{
                if try applyOperation(operation){
                    changed = true
                }
            }
        } catch let err{
            print("update failed \(err)")
            self.error = err
        }
        
        if changed {
            let values = Array(data.values)
            if let s = self.sort {
                do {
                    items = try values.sorted(by: s)
                } catch let err{
                    print("sort failed \(err)")
                    items = values
                }
            } else {
                items = values
            }
        }
//        print("updated \(items)")
    }
    
    func reset( _ handle: String){
        self.items = []
    }
    
    func onError( _ err: Error){
        self.error = err
        print("Error from Shape stream: \(err)")
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
