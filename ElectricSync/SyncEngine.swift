//
//  SyncEngine.swift
//  ElectricSync
//
//  Created by Paul Harter on 12/11/2024.
//

import Foundation


public class SyncEngine: NSObject{
    
    var dbUrl:String?
    
    public init(dbUrl: String) {
        
        self.dbUrl = dbUrl
        super.init()
        print("dbUrl \(dbUrl)")
    }
}
