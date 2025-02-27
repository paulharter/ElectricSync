//
//  BinMan.swift
//  ElectricSync
//
//  Created by Paul Harter on 12/02/2025.
//

import SwiftData


protocol Collector {
    func empty(shapeHash: Int, ctx: ModelContext)
}

class BinMan<T: PersistentModel & ElectricModel>: Collector{

    func empty(shapeHash: Int, ctx: ModelContext){
        let query = FetchDescriptor<T>()

        do {
            let objs = try ctx.fetch(query, batchSize: 1000)
            for var obj in objs {
                if obj.shapeHashes.keys.contains(shapeHash){
                    obj.shapeHashes.removeValue(forKey: shapeHash)
                    if obj.shapeHashes.count == 0 {
                        ctx.delete(obj)
                    }
                }
            }
        } catch let error{
            print("empty error \(error)")
        }
    }
}
