//
//  ElectricDecodable.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/12/2024.
//

import Foundation

protocol ElectricDecodable {
    init(from: [String: Any]) throws
    mutating func update(from: [String: Any]) throws -> Bool
}
