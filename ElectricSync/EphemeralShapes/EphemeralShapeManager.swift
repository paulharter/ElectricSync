//
//  EphemeralShapeManager.swift
//  ElectricSync
//
//  Created by Paul Harter on 06/03/2025.
//

import Combine

public class EphemeralShapeManager: ObservableObject{
    
    private var dbUrl: String
    private var publishers: [Int: WeakBox<AnyObject>] = [:]
    private var session: URLSession
    
    
    public init(dbUrl: String) {
        self.dbUrl = dbUrl
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25.0
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    public func publisher<T: ElectricModel >(table: String,
                                             whereClause: String? = nil,
                                             sort: ((T, T) throws -> Bool)? = nil) -> EphemeralShapePublisher<T> {
        
        let shapeHash: Int = ShapeIdentity(dbUrl: self.dbUrl, table: table, whereClause: whereClause).hashValue
  
        if publishers.keys.contains(shapeHash) {
            let box = publishers[shapeHash]
            if let item = box?.item {
                return (item as! EphemeralShapePublisher<T>)
            }
        }

        let publisher = EphemeralShapePublisher<T>(session: self.session, dbUrl: dbUrl, table: table, whereClause: whereClause)
        
        publishers[shapeHash] = WeakBox(item:publisher)
        publisher.start()
        return publisher
    }
}
