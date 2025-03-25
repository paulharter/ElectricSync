//
//  BasePGTests.swift
//  ElectricSync
//
//  Created by Paul Harter on 05/03/2025.
//

import XCTest
@testable import ElectricSync

import PostgresClientKit
import SwiftData
import _SwiftData_SwiftUI


class BasePGTests: XCTestCase {
    
    var connection: PostgresClientKit.Connection?
    
    
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
            let text = "INSERT INTO projects (name) VALUES ($1);"
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
            let text = "INSERT INTO projects (name) VALUES ($1);"
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
            let text = "UPDATE projects SET name = $1 WHERE name = 'Able';"
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
            let text = "SELECT * FROM projects;"
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
            let text = "TRUNCATE TABLE projects;"
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
            print("status xx: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 202 {
                print("shape deleted sucessfully")
            }
        }
        
    }
    
    
    
//    override func tearDownWithError() throws {
//        
//        guard let c = connection else { return }
////        tearDownTables(c)
//        c.close()
//    }
}
