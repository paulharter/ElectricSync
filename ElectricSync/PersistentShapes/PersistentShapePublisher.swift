//
//  DataShapeSubscriber.swift
//  ElectricSync
//
//  Created by Paul Harter on 04/12/2024.
//

import Foundation
import SwiftData
import Combine

//protocol AnyShapePublisher: AnyObject { }


enum PublisherError: Error {
    case runtimeError(String)
}

public class PersistentShapePublisher<T: PersistentModel & PersistentElectricModel>: ObservableObject, ShapeStreamSubscriber{
    
    @Published public var items: [T] = []
    @Published public var error: Error?
    @Published public var state: Int = 0
    var data: [String: T] = [:]
    private var shapeStream: ShapeStream?
    private var ctx: ModelContext
    var delegate: PersistentShapePublisherDelegate?
    var shapeRecord: ShapeRecord
    private var sort: ((T, T) throws -> Bool)?
    
    public init(session: URLSession,
                ctx: ModelContext,
                hash: Int,
                dbUrl: String,
                table: String,
                whereClause: String? = nil,
                sort: ((T, T) throws -> Bool)? = nil) throws {
        self.ctx = ctx
        self.sort = sort
        
        let entityName = Schema.entityName(for: T.self)
        
        if let record = getShapeRecord(ctx: ctx, hash: hash, modelName: entityName){
            self.shapeRecord = record
            self.shapeStream = ShapeStream(session: session,
                                           subscriber: self,
                                           dbUrl: dbUrl,
                                           table: table,
                                           whereClause: whereClause,
                                           handle: self.shapeRecord.handle,
                                           offset: self.shapeRecord.offset)
            self.initialiseFromCache()
            self.shapeRecord.lastUse = Date()
        } else {
            throw PublisherError.runtimeError("no Shape Record")
        }
    }
    
    deinit {
        print("deinit")
        self.shapeStream!.pause()
        self.shapeRecord.lastUse = Date()
        do {
            try ctx.save()
        } catch let error {
            print("deinit save failed \(error)")
        }
    }
    
    func start(){
        self.shapeStream!.start()
    }
    
    func pause() {
        self.shapeStream!.pause()
    }
    
    func getHash() -> Int {
        return self.shapeRecord.shapeHash
    }
    
    func getHandle() -> String {
        return self.shapeRecord.handle!
    }
    
    //protocol ShapeSubscriber
    func reset( _ handle: String){
        
        let keys = Array(self.data.keys)
        
        for k in keys {
            if var obj = self.data[k]{
                remove(&obj)
            }
        }
        
        self.shapeRecord.offset = "-1"
        self.shapeRecord.handle = handle
        self.items = []
        
        do {
            try ctx.save()
        } catch let err{
            print("reset failed \(err)")
            self.error = err
            self.pause()
        }
    }
    
    //protocol ShapeSubscriber
    func update(operations: [DataChangeOperation], handle: String, offset: String){
        
        var changed = false
        
        do {
            for operation in operations{
                if try applyOperation(operation){ changed = true }
            }
        } catch let err{
            print("update failed \(err)")
            self.error = err
            self.pause()
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
            
            state += 1
        }
        
        self.shapeRecord.handle = handle
        self.shapeRecord.offset = offset
        if let d = self.delegate{
            d.garbageCollect()
        }
    }
    
    func onError( _ err: Error){
        self.error = err
        print("Error from Shape stream: \(err)")
    }
    
    
    private func initialiseFromCache(){
        let query = FetchDescriptor<T>()

        do {
            var objs = try self.ctx.fetch(query)
            for obj in objs {
                if obj.shapeHashes.keys.contains(self.shapeRecord.shapeHash){
                    self.data[obj.id] = obj
                }
            }
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
            state += 1
        } catch let err{
            print("initialiseFromCache error \(err)")
            self.error = err
            self.pause() 
        }
    }
    
    private func applyOperation(_ operation: DataChangeOperation) throws -> Bool {
        
//        print("operation: \(operation.operation)")
        
        switch operation.operation{
         case "insert":
            return try upsert(operation)
         case "update":
            return try upsert(operation)
         case "delete":
            if var obj = data[operation.key] {
                remove(&obj)
                return true
            } else {
                return false
            }
         default:
            return false
         }
    }
    
    
    private func getItem(id: String) -> T?{
        let query = FetchDescriptor<T>( predicate: #Predicate { $0.id == id })

        do {
            let values = try ctx.fetch(query)
            if values.count > 0 {
                return values[0]
            } else {
                return nil
            }
            
        } catch {
            return nil
        }
    }
    
    
    private func upsert(_ operation: DataChangeOperation) throws -> Bool {
        
        if var obj = self.getItem(id: operation.key){
            
            let changed = try obj.update(from: operation.value)
//            print("CHANGED \(changed)")
            self.ensureShapeHash(hash: self.shapeRecord.shapeHash, obj: &obj)
            
            if !data.keys.contains(operation.key){
                data[operation.key] = obj
                return true
            } else {
                return changed
            }
        } else {
            var obj = try T.init(from: operation.value)
            self.ensureShapeHash(hash: self.shapeRecord.shapeHash, obj: &obj)
            data[operation.key] = obj
            ctx.insert(obj)
            return true
        }
    }
    
    
    private func remove(_ obj: inout T){
        data.removeValue(forKey: obj.id)
        obj.shapeHashes.removeValue(forKey: self.shapeRecord.shapeHash)

        if obj.shapeHashes.count == 0 {
            ctx.delete(obj)
        }
    }
    
    
    private func ensureShapeHash(hash: Int, obj: inout T){
       obj.shapeHashes[hash] = 1

    }
}
