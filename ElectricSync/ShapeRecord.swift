//
//  ShapeRecord.swift
//  ElectricSync
//
//  Created by Paul Harter on 21/01/2025.
//


import Foundation
import SwiftData
import CoreData


//public extension ModelContext {
//    // Computed property to access the underlying NSManagedObjectContext
//    var managedObjectContext: NSManagedObjectContext? {
//        
//        guard let managedObjectContext = getMirrorChildValue(of: self.container, childName: "_nsContext") as? NSManagedObjectContext else {
//            print("failed to get managedObjectContext ")
//            return nil
//        }
//        return managedObjectContext
//    }
//
//    // Computed property to access the NSPersistentStoreCoordinator
//    var coordinator: NSPersistentStoreCoordinator? {
//        managedObjectContext?.persistentStoreCoordinator
//    }
//}
//
//func getMirrorChildValue(of object: Any, childName: String) -> Any? {
//    
//    
//    for child in Mirror(reflecting: object).children{
//        print("child: \(String(describing: child.label))")
//    }
//    
//    guard let child = Mirror(reflecting: object).children.first(where: { $0.label == childName }) else {
//        return nil
//    }
//
//    return child.value
//}

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






