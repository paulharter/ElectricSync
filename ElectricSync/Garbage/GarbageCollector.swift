//
//  GarbageCollector.swift
//  ElectricSync
//
//  Created by Paul Harter on 27/02/2025.
//

import SwiftData

class GarbageCollector{
    
    private var ctx: ModelContext
    private var bytesLimit: UInt64
    private var timeLimit: TimeInterval
    private var dbFilePaths: [String] = []
    var binMen: [String: Collector] = [:]

    init(ctx: ModelContext, bytesLimit: UInt64, timeLimit: TimeInterval) {
        self.ctx = ctx
        self.bytesLimit = bytesLimit
        self.timeLimit = timeLimit
    }
    
    func calcFilePaths(){
        var paths: [String] = []
        for config in self.ctx.container.configurations{
            if !config.isStoredInMemoryOnly{
                paths.append(config.url.path)
                paths.append("\(config.url.path)-shm")
                paths.append("\(config.url.path)-wal")
            }
        }
        print("paths \(paths)")
        self.dbFilePaths = paths
    }
    
    func addType<T: PersistentModel & ElectricModel>(type: T.Type){
        let entityName = Schema.entityName(for: T.self)
        self.binMen[entityName] =  BinMan<T>()
    }
    
    func collect(entityName: String, shapeHash: Int){
        if let binMan = binMen[entityName] {
            binMan.empty(shapeHash: shapeHash, ctx: self.ctx)
        }
    }
    
    func checkTheTheTrash(activeShapeHashes: [Int]){
        
        self.calcFilePaths()
        if self.dbFilePaths.count > 0  {
            while self.dbSize() > self.bytesLimit {
                if !self.purgeOldestShape(activeShapeHashes: activeShapeHashes){
                    break
                }
            }
        }
    }
    
    func dbSize() -> UInt64{
        
        do {
            try self.ctx.save()
        } catch {
            print("Error: \(error)")
        }
        
        
        var size: UInt64 = 0
        for filePath in self.dbFilePaths {
            do {
                let attr = try FileManager.default.attributesOfItem(atPath: filePath)
                size +=  attr[FileAttributeKey.size] as! UInt64
            } catch {
                print("Error: \(error)")
            }
        }
        return size
    }
    
    func purgeOldestShape(activeShapeHashes: [Int]) -> Bool {
        if let shapeRecord = getOldestShapeRecord(ctx: self.ctx){
            if shapeRecord.lastUse < Date.now - self.timeLimit {
                if !activeShapeHashes.contains(shapeRecord.shapeHash) {
                    self.collect(entityName: shapeRecord.modelName, shapeHash: shapeRecord.shapeHash)
                    do {
                        self.ctx.delete(shapeRecord)
                        try self.ctx.save()
                    } catch {
                        print("Error: \(error)")
                    }
                    return true
                }
            }
        }
        return false
    }
}
