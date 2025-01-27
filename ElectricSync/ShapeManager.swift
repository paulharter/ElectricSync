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
    
    init(ctx: ModelContext, dbUrl: String) {
        self.ctx = ctx
        self.dbUrl = dbUrl
    }
    
    func publisher<T: PersistentModel & ElectricModel >(table: String, whereClause: String? = nil) throws -> ShapePublisher<T> {
        
        let subscriptionHash = SubscriptionIdentity(dbUrl: self.dbUrl, table: table, whereClause: whereClause).hashValue
        
        if publishers.keys.contains(subscriptionHash) {
            let box = publishers[subscriptionHash]
            if let item = box?.item {
                return (item as! ShapePublisher<T>)
            }
        }

        let publisher = try ShapePublisher<T>(ctx: self.ctx, hash: subscriptionHash, dbUrl: dbUrl, table: table, whereClause: whereClause)
        publishers[subscriptionHash] = WeakBox(item:publisher)
        return publisher
    }
}
