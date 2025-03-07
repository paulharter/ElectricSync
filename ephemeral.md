# Ephemeral Shapes


The `EphemeralShapePublisher" keeps an array in memory in sync with your shape for the lifetime of the publisher. 

## Usage

Define your object type, it should be a struct that conform to the 'ElectricModel' protocol:

```swift
protocol ElectricModel: Hashable & Identifiable{
    init(from: [String: Any]) throws
    mutating func update(from: [String: Any]) throws -> Bool
    var id : String { get }
}
```

You have to implement the init and update methods, these handle insert and update operations from Electric, giving you a `[String: Any]` holding the data.

for example:

```
struct Project: ElectricModel{

    var id: String
    var name: String
    
    init(from: [String: Any]) throws {
        guard let id = from["id"] as? String else { throw DecodeError.runtimeError("id is missing")}
        guard let name = from["name"] as? String else { throw DecodeError.runtimeError("name is missing")}
        self.id = id
        self.name = name
    }

    mutating func update(from: [String: Any]) throws -> Bool {
        var changed = false
        if let name = from["name"] as? String {
            if self.name != name {
                self.name = name
                changed = true
            }
        }
        return changed
    }
}

```

Next create a `EphemeralShapeManager` in your App giving it the url of your Electric.

And from the `EphemeralShapeManager` create an `EphemeralShapePublisher` for the table you want (optionally with a where clause and sort function) and pass it into a View to use.

You can pass it the `EphemeralShapeManager` down to other views as an `environmentObject` so they can create other `EphemeralShapePublisher` as needed

```swift
import SwiftUI
import ElectricSync

@main
struct MyApp: App {

    var shapeManager: EphemeralShapeManager?
    var projectsPublisher: EphemeralShapePublisher<Project>?
    
    init() {
        self.shapeManager = EphemeralShapeManager(dbUrl: "http://127.0.0.1:3000")
        self.projectsPublisher = self.shapeManager!.publisher(table: "projects", sort: { one, two in
            return one.name > two.name
        })
    }
    
    var body: some Scene {
        WindowGroup {
            if let publisher = self.projectsPublisher{
                ContentView(projectsPublisher: publisher)
            }
        }.environmentObject(self.shapeManager!)
    }
}

```

and then use the `EphemeralShapePublisher` in a View:

```swift
import SwiftUI
import ElectricSync

struct ContentView: View {
    @StateObject var projectsPublisher: EphemeralShapePublisher<Project>

    var body: some View {
        List {
            ForEach(projectsPublisher.items) { project in
                Text(project.name)
            }
        }
    }
}
```
