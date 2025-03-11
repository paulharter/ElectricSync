//
//  EphemeralSyncTests.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/03/2025.
//


import XCTest
@testable import ElectricSync

import PostgresClientKit
import SwiftData
import _SwiftData_SwiftUI
import Combine


final class EphemeralSyncTests: BasePGTests {
    
    
    
    @MainActor func testCleanup() async throws {

        let shapeManager = EphemeralShapeManager(dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        var publisher : EphemeralShapePublisher<TestProject2>? = shapeManager.publisher(table: "projects")
//
        let handle = await publisher!.getHandle()
        let shapeHash = await publisher!.shapeHash
//
//        subscription = nil
        print("hello")
        publisher = nil
        print("hello 2")
//        XCTAssertTrue(names == expected)
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        defer { deleteShape(handle: handle) }
        
        
        let pub: EphemeralShapePublisher<TestProject2>? = shapeManager.publisherForShapeHash(shapeHash: shapeHash)

        XCTAssertTrue(pub == nil)
    }
    
    
    
    
    func testGetsValues() async throws {

        let shapeManager = EphemeralShapeManager(dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        var publisher : EphemeralShapePublisher<TestProject2>? = try await shapeManager.publisher(table: "projects")

//        var subscription: AnyCancellable? = publisher!.objectWillChange.sink { _ in
//            expectation.fulfill()
//        }
//        
//        await fulfillment(of: [expectation], timeout: 4.0, enforceOrder: true)
//
//    
//        var names = Set<String>()
//        for project in publisher!.items {
//            names.insert(project.name)
//        }
//        let expected: Set = ["Able", "Baker", "Charlie"]
//        
        let handle = await publisher!.getHandle()
//        
//        subscription = nil
        publisher = nil
//        XCTAssertTrue(names == expected)
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        defer { deleteShape(handle: handle) }

//        XCTAssertTrue(names == expected)
    }
    
    
//    func testGetsValues2() async throws {
//
//        let shapeManager = EphemeralShapeManager(dbUrl: "http://localhost:3000")
//
//        let expectation = XCTestExpectation(description: "get some projects")
//        let publisher : EphemeralShapePublisher<TestProject2> = try shapeManager.publisher(table: "projects")
//        var subscription = publisher.objectWillChange.sink { _ in
//            expectation.fulfill()
//        }
//        
//        await fulfillment(of: [expectation], timeout: 4.0, enforceOrder: true)
//    
//        var names = Set<String>()
//        for project in publisher.items {
//            names.insert(project.name)
//        }
//        let expected: Set = ["Able", "Baker", "Charlie"]
//        
//        defer { deleteShape(handle: publisher.getHandle()) }
//
//        XCTAssertTrue(names == expected)
//    }
    
    
    @MainActor func testGetsValuesSorted() async throws {

        let shapeManager = EphemeralShapeManager(dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        let publisher : EphemeralShapePublisher<TestProject2> = shapeManager.publisher(table: "projects",
                                                                                       sort: { one, two in
            return one.name > two.name
        })
        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 4.0, enforceOrder: true)
    
        defer { deleteShape(handle: publisher.getHandle()) }
        
        print("publisher.items \(publisher.items)")

        XCTAssertTrue(publisher.items[0].name == "Charlie")
    }
    
    
    
    @MainActor func testShapeManagerGivesSamePublisher() async throws {
        
        let shapeManager = EphemeralShapeManager(dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        let expectation3 = XCTestExpectation(description: "get some projects2")
        let publisher : EphemeralShapePublisher<TestProject> = try await shapeManager.publisher(table: "projects")
        let publisher2 : EphemeralShapePublisher<TestProject> = try await shapeManager.publisher(table: "projects")
        let publisher3 : EphemeralShapePublisher<TestProject> = try await shapeManager.publisher(table: "projects", whereClause: "name='Able'")
        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        var subscription3 = publisher3.objectWillChange.sink { _ in
            expectation3.fulfill()
        }
        
        await fulfillment(of: [expectation, expectation3], timeout: 4.0, enforceOrder: false)
        
        
        defer {deleteShape(handle: publisher.getHandle())}
        defer {deleteShape(handle: publisher3.getHandle())}

        XCTAssertEqual(ObjectIdentifier(publisher), ObjectIdentifier(publisher2))
        XCTAssertNotEqual(ObjectIdentifier(publisher), ObjectIdentifier(publisher3))
        
        var names = Set<String>()
        for project in publisher3.items {
            names.insert(project.name)
        }

        let expected: Set = ["Able"]
        XCTAssertTrue(names == expected)
    }
    
    
    @MainActor func testChangeRow() async throws {
        
        let shapeManager = EphemeralShapeManager(dbUrl: "http://localhost:3000")
        let expectation = XCTestExpectation(description: "get some projects")
        let publisher : EphemeralShapePublisher<TestProject> = try await shapeManager.publisher(table: "projects")
        

        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
            
        }
        
        await fulfillment(of: [expectation], timeout: 10.0, enforceOrder: false)
        
        subscription.cancel()
        
        
        var names = Set<String>()
        for project in publisher.items {
            names.insert(project.name)
        }
        let expected: Set = ["Able", "Baker", "Charlie"]

        XCTAssertTrue(names == expected)
        
        let expectation2 = XCTestExpectation(description: "changes")
        
        var subscription2 = publisher.objectWillChange.sink { _ in
            print("got a change")
            expectation2.fulfill()
        }
        
        changeAProject(connection!)

        await fulfillment(of: [expectation2], timeout: 20.0, enforceOrder: false)

        
        var names2 = Set<String>()
        for project in await publisher.items {
            names2.insert(project.name)
        }
        let expected2: Set = ["Baker", "Charlie", "Dog"]

        XCTAssertTrue(names2 == expected2)
        await deleteShape(handle: publisher.getHandle())
    }
}
