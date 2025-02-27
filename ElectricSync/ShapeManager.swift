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


protocol ShapePublisherDelegate {
    func garbageCollect()
}


public class ShapeManager: ShapePublisherDelegate{
    
    private var ctx: ModelContext
    private var dbUrl: String
    private var publishers: [Int: WeakBox<AnyObject>] = [:]
    var garbageCollector: GarbageCollector
    private var lastGarbageCollection: Date
    
    
    private var someTypes: [String: any PersistentModel.Type] = [:]
    
    init(ctx: ModelContext,
         dbUrl: String,
         bytesLimit: UInt64 = UInt64(1024 * 1024 * 500), // 500MB
         timeLimit: TimeInterval = TimeInterval(60 * 60 * 24 * 7)) // One week
    {
        self.ctx = ctx
        self.dbUrl = dbUrl
        self.garbageCollector = GarbageCollector(ctx: ctx, bytesLimit: bytesLimit, timeLimit: timeLimit)
        self.lastGarbageCollection = Date.now
    }
    
    convenience init(for forTypes: any (ElectricModel & PersistentModel).Type...,
                     context: ModelContext,
                     dbUrl: String,
                     bytesLimit: UInt64 = UInt64(1024 * 1024 * 500),
                     timeLimit: TimeInterval = TimeInterval(60 * 60 * 24 * 7)) {
        self.init(ctx: context, dbUrl: dbUrl, bytesLimit: bytesLimit, timeLimit: timeLimit)
        for type in forTypes{
            self.garbageCollector.addType(type: type)
        }
    }
    
    func publisher<T: PersistentModel & ElectricModel >(table: String, whereClause: String? = nil) throws -> ShapePublisher<T> {
        
        let shapeHash: Int = SubscriptionIdentity(dbUrl: self.dbUrl, table: table, whereClause: whereClause).hashValue
  
        if publishers.keys.contains(shapeHash) {
            let box = publishers[shapeHash]
            if let item = box?.item {
                return (item as! ShapePublisher<T>)
            }
        }

        let publisher = try ShapePublisher<T>(ctx: self.ctx, hash: shapeHash, dbUrl: dbUrl, table: table, whereClause: whereClause)
        
        publishers[shapeHash] = WeakBox(item:publisher)
        publisher.delegate = self
        publisher.start()
        return publisher
    }
    
    func garbageCollect(){
        // roughly every 10 minutes while being used
        let now = Date.now
        if now > self.lastGarbageCollection + TimeInterval(60 * 10){
            self.garbageCollector.checkTheTheTrash(activeShapeHashes: Array(publishers.keys))
            self.lastGarbageCollection = now
        }
    }
}
