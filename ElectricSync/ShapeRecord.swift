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
    var handle: String?
    var offset: String
    @Attribute(.unique) var hash: Int
    
    required init(hash: Int, handle: String?, offset: String) {
        self.hash = hash
        self.handle = handle
        self.offset = offset
    }
}
