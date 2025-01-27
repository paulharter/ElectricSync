//
//  ElectricSyncTests.swift
//  ElectricSyncTests
//
//  Created by Paul Harter on 12/11/2024.
//

import XCTest
@testable import ElectricSync

import PostgresClientKit
import SwiftData


extension Task where Failure == Error {
    /// Performs an async task in a sync context.
    ///
    /// - Note: This function blocks the thread until the given operation is finished. The caller is responsible for managing multithreading.
    static func synchronous(priority: TaskPriority? = nil, operation: @escaping @Sendable () async throws -> Success) {
        let semaphore = DispatchSemaphore(value: 0)

        Task(priority: priority) {
            defer { semaphore.signal() }
            return try await operation()
        }

        semaphore.wait()
    }
}


final class ElectricSyncTests: XCTestCase {
    
    private var connection: PostgresClientKit.Connection?
    

    override func setUpWithError() throws {
        var configuration = PostgresClientKit.ConnectionConfiguration()
        configuration.host = "localhost"
        configuration.port = 54321
        configuration.database = "electric"
        configuration.user = "postgres"
        configuration.ssl = false
        configuration.credential = .scramSHA256(password: "password")
        
        do {
            connection = try PostgresClientKit.Connection(configuration: configuration)
            setUpStuff(connection!)
        } catch {
            print("connection failed")
            print(error)
        }
    }
    
    func setUpStuff(_ connection: PostgresClientKit.Connection) {
        setUpTables(connection)
        
        let projectsCount = checkProjects(connection)
        

        clearProjects(connection)
        addSomeProjects(connection)
        
        
    }
    
    func setUpTables(_ connection: PostgresClientKit.Connection) {
        do {
            let text = "CREATE TABLE IF NOT EXISTS projects (id SERIAL PRIMARY KEY, name varchar(255));"
            let statement = try connection.prepareStatement(text: text)
            defer { statement.close() }

            let cursor = try statement.execute()
            cursor.close()
        } catch {
            print("setUpTables failed")
            print(error)
        }
    }
    
    
    func addSomeProjects(_ connection: PostgresClientKit.Connection) {
        do {
            let text = "INSERT INTO projects (name) VALUES ($1)"
            let statement = try connection.prepareStatement(text: text)
            defer { statement.close() }

            var cursor = try statement.execute(parameterValues: [ "Able" ])
            cursor = try statement.execute(parameterValues: [ "Baker" ])
            cursor = try statement.execute(parameterValues: [ "Charlie" ])
            cursor.close()
            print("addSomeProjects")
        } catch {
            print("addSomeProjects failed")
            print(error)
        }
    }
    
    func addOneMoreProject(_ connection: PostgresClientKit.Connection) {
        do {
            let text = "INSERT INTO projects (name) VALUES ($1)"
            let statement = try connection.prepareStatement(text: text)
            defer { statement.close() }

            var cursor = try statement.execute(parameterValues: [ "Easy" ])

            cursor.close()
            print("addOneMoreProject")
        } catch {
            print("addOneMoreProject failed")
            print(error)
        }
    }
    
    
    func changeAProject(_ connection: PostgresClientKit.Connection) {
        do {
            let text = "UPDATE projects SET name = $1 WHERE name = 'Able'"
            let statement = try connection.prepareStatement(text: text)
            defer { statement.close() }

            var cursor = try statement.execute(parameterValues: [ "Dog" ])
            cursor.close()
            print("changeAProject done")
        } catch {
            print("changeAProject failed")
            print(error)
        }
    }
    
    func checkProjects(_ connection: PostgresClientKit.Connection) -> Int {
        do {
            let text = "SELECT * FROM projects"
            let statement = try connection.prepareStatement(text: text)
            defer { statement.close() }
            let cursor = try statement.execute()
            defer { cursor.close() }
            
            var counter: Int = 0
            
            for _ in cursor {
                    counter += 1
            }
            return counter
        } catch {
            print("checkProjects failed")
            print(error)
        }
        return 0
    }
    
    func clearProjects(_ connection: PostgresClientKit.Connection){
        do {
            let text = "TRUNCATE TABLE projects"
            let statement = try connection.prepareStatement(text: text)
            defer { statement.close() }
            let cursor = try statement.execute()
            cursor.close()
        } catch {
            print("clearProjects failed")
            print(error)
        }
    }

    
    func tearDownTables(_ connection: PostgresClientKit.Connection) {
        do {
            let text = "DROP TABLE projects;"
            let statement = try connection.prepareStatement(text: text)
            defer { statement.close() }

            let cursor = try statement.execute()
            cursor.close()
        } catch {
            print("tearDownTables failed")
            print(error)
        }
    }
    
    func deleteShape(handle: String) {
        
        var components = URLComponents(string: "http://localhost:3000/v1/shape")
        components?.queryItems = [ URLQueryItem(name: "handle", value: handle)]

        var request = URLRequest(url: components!.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4)
        request.httpMethod = "DELETE"
        
        let request2 = request

        
        Task.synchronous {
            let (data, response) = try await URLSession.shared.data(for: request2)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }

            let headers = httpResponse.allHeaderFields
            print("status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 202 {
                    print("shape deleted sucessfully")
            }
        } // 👈 No `await` keyword for calling the `Task.synchronous `

    }
    
 

    override func tearDownWithError() throws {

        guard let c = connection else { return }
//        tearDownTables(c)
        c.close()
    }

    func testSubscriptionGetsValues() async throws{

        let subscriber = TestSubscriber()
        let subscription = ShapeSubscription(subscriber: subscriber, dbUrl: "http://localhost:3000", table: "projects")
        
        let operationCounter = subscriber.counter
        subscription.start()
        try await subscriber.waitForNextUpdate(operationCounter)
        subscription.pause()
        
        var names = Set<String>()
        
        for (_, v) in subscriber.values {
            names.insert(v["name"] as! String)
        }

        let expected: Set = ["Able", "Baker", "Charlie"]
        defer { deleteShape(handle: subscription.handle!)}
        XCTAssertTrue(names == expected)
        //tidy up
        
        
    }
    
    
    @MainActor func testShapeManager() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        let container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        let context = container.mainContext
        
        let shapeManager = ShapeManager(ctx: context, dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        let publisher : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects")
        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 4.0, enforceOrder: true)
    
        var names = Set<String>()
        for project in publisher.items {
            names.insert(project.name)
        }
        let expected: Set = ["Able", "Baker", "Charlie"]
        
        defer { deleteShape(handle: publisher.getHandle()) }

        
        print("names \(names)")
        XCTAssertTrue(names == expected)
        

        let query = FetchDescriptor<TestProject>()
        var values = try context.fetch(query)
        values.sort()
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0].name, "Able")
        
        
        
        
    }
    
    
    @MainActor func testShapeManagerGivesSamePublisher() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        let container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        let context = container.mainContext
        
        let shapeManager = ShapeManager(ctx: context, dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        let expectation3 = XCTestExpectation(description: "get some projects2")
        let publisher : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects")
        let publisher2 : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects")
        let publisher3 : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects", whereClause: "name='Able'")
        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        var subscription3 = publisher3.objectWillChange.sink { _ in
            expectation3.fulfill()
        }
        
        await fulfillment(of: [expectation, expectation3], timeout: 4.0, enforceOrder: false)
        
        
        defer {deleteShape(handle: publisher.getHandle())}
        defer {deleteShape(handle: publisher3.getHandle())}

        XCTAssertEqual(publisher.getHash(), publisher2.getHash())
        XCTAssertEqual(ObjectIdentifier(publisher), ObjectIdentifier(publisher2))
        XCTAssertNotEqual(ObjectIdentifier(publisher), ObjectIdentifier(publisher3))
        
        var names = Set<String>()
        for project in publisher3.items {
            names.insert(project.name)
        }
        
        print("names \(names)")
        
        let expected: Set = ["Able"]
        XCTAssertTrue(names == expected)

        
    }
    
    
    @MainActor func testChangeRow() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        let container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        let context = container.mainContext
        
        let shapeManager = ShapeManager(ctx: context, dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        let publisher : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects")
        
//        var subscription : AnyCancellable
//        
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
        
        print("names \(names)")
        
        XCTAssertTrue(names == expected)
        
        
        let expectation2 = XCTestExpectation(description: "changes")
        
        
        var subscription2 = publisher.objectWillChange.sink { _ in
            expectation2.fulfill()
        }
        
        changeAProject(connection!)
        
        
        deleteShape(handle: publisher.getHandle()) 
        
        
        await fulfillment(of: [expectation2], timeout: 10.0, enforceOrder: false)
        
        
        
        
        
        var names2 = Set<String>()
        for project in publisher.items {
            names2.insert(project.name)
        }
        let expected2: Set = ["Baker", "Charlie", "Dog"]
        
        print("names2 \(names2)")
        
        XCTAssertTrue(names2 == expected2)
        
       

    }



}
