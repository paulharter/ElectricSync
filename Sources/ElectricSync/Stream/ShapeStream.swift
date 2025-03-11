//
//  ShapeStream2.swift
//  ElectricSync
//
//  Created by Paul Harter on 10/03/2025.
//

//
//  ShapeSubscription.swift
//  ElectricSync
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation


func startShapeStream(session: URLSession,
                      subscriber: ShapeStreamSubscriber?,
                      dbUrl: String,
                      table: String,
                      whereClause: String? = nil,
                      handle: String? = nil,
                      offset: String = "-1") {

    let stream = ShapeStream(session: session,
                             subscriber: subscriber,
                             dbUrl: dbUrl,
                             table: table,
                             whereClause: whereClause,
                             handle: handle,
                             offset: offset)
    
    Task {await stream.start()}
}


public class ShapeStream{
    
    private let dbUrl:String
    private let table: String
    private let whereClause: String?
    
    private var offset: String
    public  var handle: String?
    private var cursor: String?
    private var live: Bool = false
    private var operations: [DataChangeOperation] = []
    private var active: Bool = true
    private weak var subscriber: ShapeStreamSubscriber?
    private var session: URLSession
    
    init(session: URLSession,
         subscriber: ShapeStreamSubscriber?,
         dbUrl: String,
         table: String,
         whereClause: String? = nil,
         handle: String? = nil,
         offset: String = "-1") {
        
        self.table = table
        self.session = session
        self.handle = handle
        self.offset = offset
        self.whereClause = whereClause
        self.dbUrl = dbUrl
        self.subscriber = subscriber
    }
    
    deinit {
        print("deinit ShapeStream2")
    }
    
    public func start() async {

        self.active = true
        while active{
            do {
                self.active = try await request()
            } catch let error {
                self.active = false
                await self.subscriber?.onError(error)
            }
        }
//        print("bye bye!")
    }

    public func stop(){
        self.active = false
    }
    
    public func request() async throws -> Bool{
        
        guard let url = buildUrl() else {
            throw StreamError.runtimeError("Error building URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
            
        let (data, response) = try await self.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StreamError.runtimeError("Invalid response")
        }

        if active == false{
            return false
        }

        let headers = httpResponse.allHeaderFields
//            print("status: \(httpResponse.statusCode)")
        if httpResponse.statusCode == 409 {
//                print("conflict reading Location")
            if let location = headers["Location"] as? String{
                if let urlComponent = URLComponents(string: location) {
                    let queryItems = urlComponent.queryItems
                    if let newHandle = queryItems?.first(where: { $0.name == "handle" })?.value{
                        return await refetch(newHandle: newHandle)
                    }
                }
            }
            return true
        }

        if httpResponse.statusCode > 204 {
            throw StreamError.runtimeError("HTTP Error: \(httpResponse.statusCode)")
        }

        if httpResponse.statusCode == 200 {
            
            handle = headers[CTRL_HEADER.HANDLE] as? String
            offset = (headers[CTRL_HEADER.OFFSET] as? String)!
            cursor = headers[CTRL_HEADER.CURSOR] as? String
            
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for message in json{
                    if let operation = DataChangeOperation(table: table, message: message){
//                            print("\(operation.operation)")
                        operations.append(operation)
                    }
                }

            } else {
                throw StreamError.runtimeError("Failed to decode JSON")
            }
            

            if headers[CTRL_HEADER.UP_TO_DATE] != nil {
                live = true
                return await forwardOperations()
            }
        }
        return true
    }
    
    private func forwardOperations() async -> Bool {
        if let sub = self.subscriber{
            await sub.update(operations: self.operations, handle: self.handle!, offset: self.offset)
            self.operations = []
            return true
        } else {
            return false
        }
    }
    
    private func refetch(newHandle: String) async -> Bool{
        
        if let sub = self.subscriber{
            handle = newHandle
            offset = "-1"
            await sub.reset(newHandle)
            return true
        } else {
            return false
        }
    }
    
    private func buildUrl() -> URL? {
        var components = URLComponents(string: "\(dbUrl)/v1/shape")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "table", value: table),
            URLQueryItem(name: "offset", value: offset)
        ]

        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        if let handle = handle {
            queryItems.append(URLQueryItem(name: "handle", value: handle))
        }

        if live {
            queryItems.append(URLQueryItem(name: "live", value: "true"))
        }

        if let whereClause = whereClause {
            queryItems.append(URLQueryItem(name: "where", value: whereClause))
        }

        components?.queryItems = queryItems
        return components?.url
    }
}
