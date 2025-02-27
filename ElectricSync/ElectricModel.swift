//
//  ElectricDecodable.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/12/2024.
//

import Foundation
import SwiftData


enum DecodeError: Error {
    case runtimeError(String)
}

protocol ElectricModel: Comparable & Hashable & Identifiable{
    init(from: [String: Any]) throws
    mutating func update(from: [String: Any]) throws -> Bool
    var shapeHashes :  [Int: Int] { get set }
    var id : String { get }
}
