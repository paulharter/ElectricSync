//
//  ListPublisherFactory.swift
//  ElectricSync
//
//  Created by Paul Harter on 21/01/2025.
//

import Foundation
import SwiftData
import Combine


struct WeakBox<ItemType: AnyObject> {
    weak var item: ItemType?

    init(item: ItemType?) {
        self.item = item
    }
}


protocol PersistentShapePublisherDelegate {
    func garbageCollect()
}


public class PersistentShapeManager: ObservableObject, PersistentShapePublisherDelegate{
    
    private var ctx: ModelContext
    private var dbUrl: String
    private var publishers: [Int: WeakBox<AnyObject>] = [:]
    var garbageCollector: GarbageCollector
    private var lastGarbageCollection: Date
    private var session: URLSession
    
    
//    private var someTypes: [String: any PersistentModel.Type] = [:]
    
    public init(ctx: ModelContext,
         dbUrl: String,
         bytesLimit: UInt64 = UInt64(1024 * 1024 * 500), // 500MB
         timeLimit: TimeInterval = TimeInterval(60 * 60 * 24 * 7)) // One week
    {
        self.ctx = ctx
        self.dbUrl = dbUrl
        self.garbageCollector = GarbageCollector(ctx: ctx, bytesLimit: bytesLimit, timeLimit: timeLimit)
        self.lastGarbageCollection = Date.now
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25.0
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    public convenience init(for forTypes: any (PersistentElectricModel & PersistentModel).Type...,
                     context: ModelContext,
                     dbUrl: String,
                     bytesLimit: UInt64 = UInt64(1024 * 1024 * 500),
                     timeLimit: TimeInterval = TimeInterval(60 * 60 * 24 * 7)) {
        self.init(ctx: context, dbUrl: dbUrl, bytesLimit: bytesLimit, timeLimit: timeLimit)
        for type in forTypes{
            self.garbageCollector.addType(type: type)
        }
    }
    
    public func publisher<T: PersistentModel & PersistentElectricModel >(table: String, whereClause: String? = nil) throws -> PersistentShapePublisher<T> {
        
        let shapeHash: Int = ShapeIdentity(dbUrl: self.dbUrl, table: table, whereClause: whereClause).hashValue
  
        if publishers.keys.contains(shapeHash) {
            let box = publishers[shapeHash]
            if let item = box?.item {
                return (item as! PersistentShapePublisher<T>)
            }
        }

        let publisher = try PersistentShapePublisher<T>(session: self.session,
                                                        ctx: self.ctx,
                                                        hash: shapeHash,
                                                        dbUrl: dbUrl,
                                                        table: table,
                                                        whereClause: whereClause)
        
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
