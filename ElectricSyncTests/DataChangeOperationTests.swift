//
//  ChangeOperationTests.swift
//  ElectricSyncTests
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation


import XCTest
@testable import ElectricSync


final class DataChangeOperationTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    
    func shallowAssertDictsEqual(one: [String: Any], two: [String: Any]){
        
        XCTAssertEqual(one.keys, two.keys)
        
        for (k, v) in one {
            XCTAssertEqual("\(type(of: v))", "\(type(of: two[k]!))")
            XCTAssertEqual("\(v)", "\(two[k]!)")
        }
        
    }

    func testOperationFromMessage() throws {

        let message: [String: Any]  = [
            "headers": [
            "operation": "insert",
            "control": "up-to-date"
            ],
            "offset": 19340,
            "key": "issue-2",
            "value": [
            "id": "issue-2",
            "title": "Hello",
            "status": "backlog"
            ]
            ]
        
        let operation = DataChangeOperation(table: "projects", message: message)
        
        let expected: [String: Any]  = [
            "id": "issue-2",
            "title": "Hello",
            "status": "backlog"
            ]
        
        XCTAssertTrue(operation != nil)
        XCTAssertEqual(operation!.table, "projects")
        XCTAssertEqual(operation!.key, "issue-2")
        shallowAssertDictsEqual(one:operation!.value, two: expected )
        
    }
    
    
    func testOperationFromMessageFailsOnOperationName() throws {

        let message: [String: Any]  = [
            "headers": [
            "operation": "write",
            "control": "up-to-date"
            ],
            "offset": 19340,
            "key": "issue-2",
            "value": [
            "id": "issue-2",
            "title": "Hello",
            "status": "backlog"
            ]
            ]
        
        let operation = DataChangeOperation(table: "projects", message: message)
        
        XCTAssertNil(operation)
        
    }



}
