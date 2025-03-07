//
//  ShapeSubscriber.swift
//  ElectricSync
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation

protocol ShapeStreamSubscriber: AnyObject {
    func update(operations: [DataChangeOperation], handle: String, offset: String)
    func reset( _ handle: String)
    func onError( _ error: Error)
}
