//
//  BinMan.swift
//  ElectricSync
//
//  Created by Paul Harter on 12/02/2025.
//

import SwiftData

class BinMan<T: PersistentModel & ElectricModel>{
    
    private var ctx: ModelContext
    var shapeHash: Int

    init(ctx: ModelContext, shapeHash: Int) {
        self.shapeHash = shapeHash
        self.ctx = ctx
    }
    
    
    private func empty(){
        let query = FetchDescriptor<T>()
        
        do {
            var objs = try self.ctx.fetch(query)
            for var obj in objs {
                if obj.shapeHashes.keys.contains(self.shapeHash){
                    obj.shapeHashes.removeValue(forKey: self.shapeHash)
                    if obj.shapeHashes.count == 0 {
                        self.ctx.delete(obj)
                    }
                }
            }

        } catch let error{
            print("empty error \(error)")
        }
    }

}
