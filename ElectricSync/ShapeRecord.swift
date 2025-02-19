//
//  ShapeRecord.swift
//  ElectricSync
//
//  Created by Paul Harter on 21/01/2025.
//


import Foundation
import SwiftData


@Model
class ShapeRecord{
    var modelName: String
    var handle: String?
    var offset: String
    var lastUse: Date
    @Attribute(.unique) var shapeHash: Int
    
    required init(modelName: String, hash: Int, handle: String?, offset: String) {
        self.shapeHash = hash
        self.handle = handle
        self.offset = offset
        self.lastUse = Date()
        self.modelName = modelName
    }
    
}

func getShapeRecord(ctx: ModelContext, hash: Int, modelName: String) -> ShapeRecord?{
    let query = FetchDescriptor<ShapeRecord>( predicate: #Predicate { $0.shapeHash == hash })

    do {
        let values = try ctx.fetch(query)
        if values.count > 0 {
            return values[0]
        } else {
            
            print("modelName 2 \(modelName)")
            let record = ShapeRecord(modelName: modelName, hash: hash, handle: nil, offset: "-1")
            ctx.insert(record)

            do{
                try ctx.save()
            } catch let error {
                print("save error \(error)")
            }
            return record
        }
        
    } catch {
        return nil
    }
}

func getOldestShapeRecord(ctx: ModelContext) -> ShapeRecord?{

    var query = FetchDescriptor<ShapeRecord>(sortBy: [.init(\.lastUse, order: .reverse)])
    
    query.fetchLimit = 1

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
