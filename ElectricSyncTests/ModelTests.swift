//
//  ModelTests.swift
//  ElectricSync
//
//  Created by Paul Harter on 23/01/2025.
//

import Foundation


import XCTest
@testable import ElectricSync


final class ModelTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCreatingModels() throws {
        let data = ["id": "12345678", "name": "Paul"]
        let project = try TestProject(from: data)
        XCTAssertEqual(project.name, "Paul")
    }


}

