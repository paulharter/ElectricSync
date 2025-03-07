//
//  ElectricDecodable.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/12/2024.
//

import Foundation
import SwiftData


public enum DecodeError: Error {
    case runtimeError(String)
}

public enum StreamError: Error {
    case runtimeError(String)
}

public protocol ElectricModel: Comparable & Hashable & Identifiable{
    init(from: [String: Any]) throws
    mutating func update(from: [String: Any]) throws -> Bool
    var id : String { get }
}


public protocol PersistentElectricModel: ElectricModel{
    var shapeHashes :  [Int: Int] { get set }
}
