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
import _SwiftData_SwiftUI


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

//            let headers = httpResponse.allHeaderFields
            print("status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 202 {
                    print("shape deleted sucessfully")
            }
        }

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

        XCTAssertTrue(names2 == expected2)
        
    }

    @MainActor func testShapeIdsMatchmembershipOfPublishedSets() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        let container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        let context = container.mainContext
        
        let shapeManager = ShapeManager(ctx: context, dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        let expectation2 = XCTestExpectation(description: "get some projects")
        let expectation3 = XCTestExpectation(description: "get some projects")
        let publisher : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects")
        let publisher2 : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects", whereClause: "name='Baker'")
        let publisher3 : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects", whereClause: "name='Able'")
        
        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        var subscription2 = publisher2.objectWillChange.sink { _ in
            expectation2.fulfill()
        }
        
        var subscription3 = publisher3.objectWillChange.sink { _ in
            expectation3.fulfill()
        }
        
        // have got all three subscriptions
         await fulfillment(of: [expectation, expectation2, expectation3], timeout: 4.0, enforceOrder: false)
        
        
        
        print("handle \(publisher3.getHandle())")
        
        assertPublisherNames(publisher: publisher, expectedNames: ["Able", "Baker", "Charlie"])
        assertPublisherNames(publisher: publisher2, expectedNames: ["Baker"])
        assertPublisherNames(publisher: publisher3, expectedNames: ["Able"])
        
        assertShapeIDsForName(context: context, name: "Able", shapeHashes: [publisher.getHash(), publisher3.getHash()])
        assertShapeIDsForName(context: context, name: "Baker", shapeHashes: [publisher.getHash(), publisher2.getHash()])
        assertShapeIDsForName(context: context, name: "Charlie", shapeHashes: [publisher.getHash()])
        
        defer {deleteShape(handle: publisher.getHandle())}
        defer {deleteShape(handle: publisher2.getHandle())}
        defer {deleteShape(handle: publisher3.getHandle())}
    }
    
    
    func assertPublisherNames(publisher: ShapePublisher<TestProject>, expectedNames: Set<String>){
        
        var names = Set<String>()
        for project in publisher.items {
            names.insert(project.name)
        }
        
        print("names: \(names)")
        print("expectedNames: \(expectedNames)")
        
        XCTAssertTrue(names == expectedNames)
    }
    
    func assertShapeIDsForName(context: ModelContext, name: String, shapeHashes: Set<Int>){
        
        let query = FetchDescriptor<TestProject>(
            predicate: #Predicate { $0.name == name }
        )
        do{
            let projects = try context.fetch(query)
            XCTAssertEqual(projects.count, 1)
            let project: TestProject = projects[0]
            print("keys: \(project.shapeHashes.keys)")
            print("expected: \(shapeHashes)")
            XCTAssertTrue(Set(project.shapeHashes.keys) == shapeHashes)
        } catch {
            XCTFail("couldn't find project")
        }
        

    }
    
    @MainActor func testPublisherCanReset() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        let container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        let context = container.mainContext
        
        let shapeManager = ShapeManager(ctx: context, dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        let expectation2 = XCTestExpectation(description: "get some projects")
        let expectation3 = XCTestExpectation(description: "get some projects")
        let publisher : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects")
        let publisher2 : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects", whereClause: "name='Baker'")
        let publisher3 : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects", whereClause: "name='Able'")
        
        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        var subscription2 = publisher2.objectWillChange.sink { _ in
            expectation2.fulfill()
        }
        
        var subscription3 = publisher3.objectWillChange.sink { _ in
            expectation3.fulfill()
        }
        
        // have got all three subscriptions
         await fulfillment(of: [expectation, expectation2, expectation3], timeout: 4.0, enforceOrder: false)
        
        
        
        // pause them all
        publisher.pause()
        publisher2.pause()
        publisher3.pause()
    

        assertPublisherNames(publisher: publisher, expectedNames: ["Able", "Baker", "Charlie"])
        assertPublisherNames(publisher: publisher2, expectedNames: ["Baker"])
        assertPublisherNames(publisher: publisher3, expectedNames: ["Able"])

        assertShapeIDsForName(context: context, name: "Able", shapeHashes: [publisher.getHash(), publisher3.getHash()])
        assertShapeIDsForName(context: context, name: "Baker", shapeHashes: [publisher.getHash(), publisher2.getHash()])
        assertShapeIDsForName(context: context, name: "Charlie", shapeHashes: [publisher.getHash()])
        
        
        publisher.reset("dummy_handle")
        
        assertPublisherNames(publisher: publisher, expectedNames: [])
        assertPublisherNames(publisher: publisher2, expectedNames: ["Baker"])
        assertPublisherNames(publisher: publisher3, expectedNames: ["Able"])

        assertShapeIDsForName(context: context, name: "Able", shapeHashes: [publisher3.getHash()])
        assertShapeIDsForName(context: context, name: "Baker", shapeHashes: [publisher2.getHash()])

        defer {deleteShape(handle: publisher.getHandle())}
        defer {deleteShape(handle: publisher2.getHandle())}
        do {deleteShape(handle: publisher3.getHandle())}
    }
    
    
    @MainActor func testShapeHashSaving() async throws {
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
        
        // have got all three subscriptions
         await fulfillment(of: [expectation], timeout: 4.0, enforceOrder: false)
        
        let before = publisher.getHash()
        
        try context.save()
        let after = publisher.getHash()

        XCTAssertEqual(before, after)

        assertPublisherNames(publisher: publisher, expectedNames: ["Able", "Baker", "Charlie"])
        do {deleteShape(handle: publisher.getHandle())}

    }
    
    
    @MainActor func testShapeFromCache() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        let container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        let context = container.mainContext
        
        
        let urlApp = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last
           let url = urlApp!.appendingPathComponent("default.store")
           if FileManager.default.fileExists(atPath: url.path) {
               print("swiftdata db at \(url.absoluteString)")
           }
        
        let shapeManager = ShapeManager(ctx: context, dbUrl: "http://localhost:3000")

        let expectation = XCTestExpectation(description: "get some projects")
        var publisher : ShapePublisher<TestProject>? = try shapeManager.publisher(table: "projects")

        var subscription = publisher!.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        // have got all three subscriptions
         await fulfillment(of: [expectation], timeout: 4.0, enforceOrder: false)
        
        let shapeHash = publisher!.getHash()
        let shapeHandle = publisher!.getHandle()
        
        publisher = nil

        let subscriptionHash: Int = SubscriptionIdentity(dbUrl: "http://localhost:3000", table: "projects", whereClause: nil).hashValue

        let publisher2 = try ShapePublisher<TestProject>(ctx: context, hash: subscriptionHash, dbUrl: "http://localhost:3000", table: "projects", whereClause: nil)
        
        XCTAssertEqual(publisher2.items.count, 3)
        do {deleteShape(handle: shapeHandle)}
    }
    
    
    @MainActor func testGC() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        
        var container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        container.deleteAllData()
        
        container = try ModelContainer(for:
            TestProject.self,
            ShapeRecord.self,
            configurations: configuration
        )
        
        let context = container.mainContext
        
        let shapeManager = ShapeManager(for: TestProject.self,
                                        context: context,
                                        dbUrl: "http://localhost:3000",
                                        bytesLimit: 234000,
                                        timeLimit:  TimeInterval(0.5) )
        
        shapeManager.garbageCollector.calcFilePaths()
        let sizeBefore = shapeManager.garbageCollector.dbSize()
        print("DB size: \(sizeBefore)")
        
        XCTAssertTrue(sizeBefore > 119000)
        XCTAssertTrue(sizeBefore < 120000)
                                
        let expectation = XCTestExpectation(description: "get some projects")
        let publisher : ShapePublisher<TestProject> = try shapeManager.publisher(table: "projects")

        var subscription = publisher.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        // have got all three subscriptions
         await fulfillment(of: [expectation], timeout: 4.0, enforceOrder: false)
    
        assertPublisherNames(publisher: publisher, expectedNames: ["Able", "Baker", "Charlie"])
        
        do{
            try context.save()
//            try context.parentContext.save()
        } catch {}
        
        shapeManager.garbageCollector.calcFilePaths()
        let sizeAfter = shapeManager.garbageCollector.dbSize()
        
        print("DB size: \(sizeAfter)")
        
        XCTAssertTrue(sizeAfter > 234000)
        XCTAssertTrue(sizeAfter < 235000)
        
        let purged = shapeManager.garbageCollector.purgeOldestShape(activeShapeHashes: [publisher.shapeRecord.shapeHash])
        
        XCTAssertEqual(purged, false)
        
        
        let purged2 = shapeManager.garbageCollector.purgeOldestShape(activeShapeHashes: [])
        
        XCTAssertEqual(purged2, false)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let purged3 = shapeManager.garbageCollector.purgeOldestShape(activeShapeHashes: [])
        
        XCTAssertEqual(purged3, true)
        
        do {deleteShape(handle: publisher.getHandle())}
    }
}
