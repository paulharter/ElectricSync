//
//  ShapeSubscriber.swift
//  ElectricSync
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation


protocol ShapeSubscriber {
    func operations(_: [DataChangeOperation]) -> Bool
    func subscriberId() -> String
}
