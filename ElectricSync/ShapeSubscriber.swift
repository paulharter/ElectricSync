//
//  ShapeSubscriber.swift
//  ElectricSync
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation


protocol ShapeSubscriber: AnyObject {
    func operations(_: [DataChangeOperation])
    func subscriberId() -> String
}
