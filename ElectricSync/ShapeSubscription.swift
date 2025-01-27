//
//  ShapeSubscription.swift
//  ElectricSync
//
//  Created by Paul Harter on 14/11/2024.
//

import Foundation

public class ShapeSubscription{
    
    private let dbUrl:String
    private let table: String
    private let whereClause: String?
    
    private var offset: String
    public  var handle: String?
    private var cursor: String?
    private var live: Bool = false
    private var operations: [DataChangeOperation] = []
    private var active: Bool = false
    private weak var subscriber: ShapeSubscriber?
    
    init(subscriber: ShapeSubscriber,
         dbUrl: String,
         table: String,
         whereClause: String? = nil,
         handle: String? = nil,
         offset: String = "-1") {
        
        self.table = table
        self.handle = handle
        self.offset = offset
        self.whereClause = whereClause
        self.dbUrl = dbUrl
        self.subscriber = subscriber
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
    
    private func aBadThingHappened(_ message: String){
        print("A bad thing happened: \(message)")
    }

    private func refetch(newHandle: String) {
        handle = newHandle
        offset = "-1"
        if let sub = self.subscriber{
            sub.reset(newHandle)
        }
    }
    
    private func request() async {
        
        guard let url = buildUrl() else {
            aBadThingHappened("Error building URL")
            return
        }

        do {
            print("\nurl: \(url)")
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
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
            
            // it might have been paused while waiting
            if active == false{
                return
            }

            let headers = httpResponse.allHeaderFields
            print("status: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 409 {
//                print("conflict reading Location")
                if let location = headers["Location"] as? String{
                    if let urlComponent = URLComponents(string: location) {
                        let queryItems = urlComponent.queryItems
                        if let newHandle = queryItems?.first(where: { $0.name == "handle" })?.value{
                            refetch(newHandle: newHandle)
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
                    aBadThingHappened("Failed to decode JSON")
                    return
                }
                

                if headers[CTRL_HEADER.UP_TO_DATE] != nil {
                    live = true
                    Task {
                        await MainActor.run { [weak self] in
                            self?.forwardOperations()
                        }
                    }
                }
            }
        } catch {
            print("Error fetching data: \(error)")
        }
    }
    
    private func forwardOperations() {
        subscriber!.update(operations: operations, handle: handle!, offset: offset)
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
