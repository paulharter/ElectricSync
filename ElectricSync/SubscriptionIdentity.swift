//
//  SubscriptionIdentity.swift
//  ElectricSync
//
//  Created by Paul Harter on 21/01/2025.
//


struct SubscriptionIdentity: Hashable {
    
    let dbUrl:String
    let table: String
    let whereClause: String?
    
   func hash(into hasher: inout Hasher) {
        hasher.combine(dbUrl)
        hasher.combine(table)
        hasher.combine(whereClause)
    }
    
    static func ==(lhs: SubscriptionIdentity, rhs: SubscriptionIdentity) -> Bool {
        if (lhs.whereClause == nil) {
            if (lhs.whereClause == nil) {
                return lhs.dbUrl == rhs.dbUrl && lhs.table == rhs.table
            } else {
                return false
            }
            
        } else {
            if (lhs.whereClause == nil) {
                return false
            } else {
                return lhs.dbUrl == rhs.dbUrl && lhs.table == rhs.table && lhs.whereClause == rhs.whereClause
            }
        }
      }
}


