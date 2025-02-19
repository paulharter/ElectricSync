//
//  ListPublisherFactory.swift
//  ElectricSync
//
//  Created by Paul Harter on 21/01/2025.
//

import Foundation
import SwiftData


struct WeakBox<ItemType: AnyObject> {
    weak var item: ItemType?

    init(item: ItemType?) {
        self.item = item
    }
}

public class ShapeManager{
    
    private var ctx: ModelContext
    private var dbUrl: String
    private var publishers: [Int: WeakBox<AnyObject>] = [:]
    private var purgeSemaphore = DispatchSemaphore(value: 1)
    
    init(ctx: ModelContext, dbUrl: String) {
        self.ctx = ctx
        self.dbUrl = dbUrl
//        for (name, entity) in ctx.container.schema.entitiesByName {
//            print("model \(name)")
//            print("model \(entity)")
//        }
        
    }
    
    func publisher<T: PersistentModel & ElectricModel >(table: String, whereClause: String? = nil) throws -> ShapePublisher<T> {

        
        let shapeHash: Int = SubscriptionIdentity(dbUrl: self.dbUrl, table: table, whereClause: whereClause).hashValue
  
        self.purgeSemaphore.wait()
        
        if publishers.keys.contains(shapeHash) {
            let box = publishers[shapeHash]
            if let item = box?.item {
                return (item as! ShapePublisher<T>)
            }
        }

        let publisher = try ShapePublisher<T>(ctx: self.ctx, hash: shapeHash, dbUrl: dbUrl, table: table, whereClause: whereClause)
        
        publishers[shapeHash] = WeakBox(item:publisher)
        self.purgeSemaphore.signal()
        publisher.start()
        return publisher
    }
    
    func garbageCollect(olderThan: Date){
        
        
        
    }
    
    func purgeOldestShape(){
        if var shapeRecord = getOldestShapeRecord(ctx: self.ctx){
            
            self.purgeSemaphore.wait()

            if !self.publishers.keys.contains(shapeRecord.shapeHash) {
                
                
                
            }
            
            self.purgeSemaphore.signal()
        }

    }
}
