//
//  ShapeSubscription.swift
//  ElectricSync
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation


public class ShapeSubscription: NSObject{
    
    private let dbUrl:String
    private let table: String
    private let whereClause: String?
    
    private var offset: String? = "-1"
    private var handle: String?
    private var cursor: String?
    private var live: Bool = false
    private var operations: [DataChangeOperation] = []
    private var active: Bool = false
    private var subscribers: [String:ShapeSubscriber] = [:]
    
    
    init(dbUrl: String = "http://localhost:3000", table: String, whereClause: String? = nil) {
        
        self.table = table
        self.whereClause = whereClause
        self.dbUrl = dbUrl
        super.init()
//        print("dbUrl \(dbUrl)")
    }
    
    func start() {
        active = true
        Task {
            while active {
                await request()
            }
        }
    }
    
    func pause() {
        active = false
    }
    
    
    func subscribe(_ subscriber: ShapeSubscriber) {
        subscribers[subscriber.subscriberId()] = subscriber
    }
    
    
    func unsubscribe(_ subscriber: ShapeSubscriber) {
        subscribers.removeValue(forKey: subscriber.subscriberId())
    }
    
    
    private func aBadThingHappened(_ message: String){
        print("A bad thing happened: \(message)")
    }
    

    private func refetch() {
        
    }
    
    
    
    private func request() async {
        
        guard let url = buildUrl() else {
            aBadThingHappened("Error building URL")
            return
        }

        do {
            print("\nurl: \(url)")
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
            request.httpMethod = "GET"
            
//            let start = DispatchTime.now()
            let (data, response) = try await URLSession.shared.data(for: request)
//            let end = DispatchTime.now()
//
//            let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
//            let timeInterval = Double(nanoTime) / 1_000_000_000

//            print("sec: \(timeInterval) seconds")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            let headers = httpResponse.allHeaderFields
            
            
            print("status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 409 {
                print("conflict reading Location")
                if let location = headers["Location"] as? String{
                    if let urlComponent = URLComponents(string: location) {
                        let queryItems = urlComponent.queryItems
                        let newHandle = queryItems?.first(where: { $0.name == "handle" })?.value
                        if newHandle != nil {
                            handle = newHandle
                        }
                    }
                }
                return
            }


            if httpResponse.statusCode > 204 {
                print("Error: \(httpResponse.statusCode)")
                return
            }

            if httpResponse.statusCode == 200 {
                
                
                if headers[CTRL_HEADER.MUST_REFETCH] != nil {
                    refetch()
                    return
                }
                
                handle = headers[CTRL_HEADER.HANDLE] as? String
                offset = headers[CTRL_HEADER.OFFSET] as? String
                cursor = headers[CTRL_HEADER.CURSOR] as? String
                
                
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    for message in json{
                        if let operation = DataChangeOperation(table: table, message: message){
                            print("\(operation.operation)")
                            operations.append(operation)
                        }
                    }

                } else {
                    aBadThingHappened("Failed to decode JSON")
                    return
                }
                

                if headers[CTRL_HEADER.UP_TO_DATE] != nil {
                    print("up-to-date")
                    live = true
                    forwardOperations()
                }
            }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
    
    private func forwardOperations() {
        
        var failedSubscribers: [ShapeSubscriber] = []
    
        for (_, subscriber) in subscribers {
            if !subscriber.operations(operations){
                failedSubscribers.append(subscriber)
            }
        }
        
        for failed in failedSubscribers {
            unsubscribe(failed)
        }
        
        operations = []
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
