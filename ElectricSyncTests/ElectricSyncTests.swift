//
//  ElectricSyncTests.swift
//  ElectricSyncTests
//
//  Created by Paul Harter on 12/11/2024.
//

import XCTest
@testable import ElectricSync

import PostgresClientKit


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
        
        if projectsCount != 3 {
            clearProjects(connection)
            addSomeProjects(connection)
        }
        
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
            print("hello")
        } catch {
            print("addSomeProjects failed")
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
            
            for row in cursor {
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

    override func tearDownWithError() throws {

        guard let c = connection else { return }
//        tearDownTables(c)
        c.close()
    }

    func testSubscriptionGetsValues() async throws{
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.

        
        let subscription = ShapeSubscription(table: "projects")
        let subscriber = TestSubscriber()
        subscription.subscribe(subscriber)
        
        let operationCounter = subscriber.counter
        subscription.start()
        try await subscriber.waitForNextUpdate(operationCounter)
        subscription.pause()
        
        var names = Set<String>()
        
        for (_, v) in subscriber.values {
            names.insert(v["name"] as! String)
        }

        let expected: Set = ["Able", "Baker", "Charlie"]
        XCTAssertTrue(names == expected)
        
    }

}
