//
//  TestProjectObject.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/12/2024.
//

import Foundation


enum DecodeError: Error {
    case runtimeError(String)
}


struct TestProject: ElectricDecodable, Comparable, Hashable, Identifiable{
    var id: String
    var name: String
    
    // ElectricDecodable
    init(from: [String: Any]) throws {
        guard let id = from["id"] as? String else { throw DecodeError.runtimeError("id is missing")}
        guard let name = from["name"] as? String else { throw DecodeError.runtimeError("name is missing")}
        self.id = id
        self.name = name
    }
    
    mutating func update(from: [String: Any]) throws -> Bool {
        var changed = false
        if let name = from["name"] as? String {
            if self.name != name {
                self.name = name
                changed = true
            }
        }
        return changed
    }
    
    // Comparable
    static func <(lhs: TestProject, rhs: TestProject) -> Bool {
            return lhs.name < rhs.name
    }
}
