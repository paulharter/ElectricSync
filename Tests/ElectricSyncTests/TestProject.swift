//
//  TestProjectObject.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/12/2024.
//

import Foundation
import SwiftData
@testable import ElectricSync

@Model
class TestProject: PersistentElectricModel{

    var id: String
    var name: String
    var shapeHashes: [Int: Int] = [:]
    
    required init(from: [String: Any]) throws {
        guard let id = from["id"] as? String else { throw DecodeError.runtimeError("id is missing")}
        guard let name = from["name"] as? String else { throw DecodeError.runtimeError("name is missing")}
        self.id = id
        self.name = name
    }

    func update(from: [String: Any]) throws -> Bool {
        var changed = false
        if let name = from["name"] as? String {
            if self.name != name {
                self.name = name
                changed = true
            }
        }
        return changed
    }
}
