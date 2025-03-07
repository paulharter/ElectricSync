//
//  TestProject2.swift
//  ElectricSync
//
//  Created by Paul Harter on 06/03/2025.
//

import Foundation
@testable import ElectricSync

struct TestProject2: ElectricModel{

    var id: String
    var name: String
    
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
    static func <(lhs: TestProject2, rhs: TestProject2) -> Bool {
            return lhs.name < rhs.name
    }
}
