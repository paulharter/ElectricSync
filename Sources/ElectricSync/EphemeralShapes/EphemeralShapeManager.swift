//
//  EphemeralShapeManager.swift
//  ElectricSync
//
//  Created by Paul Harter on 06/03/2025.
//

import Foundation
import Combine

public class EphemeralShapeManager: ObservableObject{
    
    private var dbUrl: String
    private var sourceId: String?
    private var sourceSecret: String?
    private var publishers: [Int: WeakBox<AnyObject>] = [:]
    private var session: URLSession
    
    
    public init(dbUrl: String, sourceId: String? = nil, sourceSecret: String? = nil) {
        self.dbUrl = dbUrl
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25.0
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        self.sourceId = sourceId
        self.sourceSecret = sourceSecret
    }
    
    @MainActor public func publisher<T: ElectricModel >(table: String,
                                             whereClause: String? = nil,
                                             sort: ((T, T) throws -> Bool)? = nil) -> EphemeralShapePublisher<T> {
        
        let shapeHash: Int = ShapeIdentity(dbUrl: self.dbUrl, table: table, whereClause: whereClause).hashValue
  
        if publishers.keys.contains(shapeHash) {
            let box = publishers[shapeHash]
            if let item = box?.item {
                return (item as! EphemeralShapePublisher<T>)
            }
        }

        let publisher = EphemeralShapePublisher<T>(shapeHash: shapeHash,
                                                   session: self.session,
                                                   dbUrl: dbUrl,
                                                   table: table,
                                                   whereClause: whereClause,
                                                   sourceId: self.sourceId,
                                                   sourceSecret: self.sourceSecret,
                                                   sort: sort)
        
        publishers[shapeHash] = WeakBox(item:publisher)
        return publisher
    }
    
    
    public func publisherForShapeHash<T>(shapeHash: Int) ->EphemeralShapePublisher<T>?{
        let box = publishers[shapeHash]
        if let item = box?.item {
            return (item as! EphemeralShapePublisher<T>)
        } else {
            return nil
        }
    }
}
