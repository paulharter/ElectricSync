# Ephemeral Shapes


The `EphemeralShapePublisher" keeps an array in memory in sync with your shape for the lifetime of the publisher. 

## Usage

Define your object type, it should be a struct that conform to the 'ElectricModel' protocol:

```swift
protocol ElectricModel: Comparable & Hashable & Identifiable{
    init(from: [String: Any]) throws
    mutating func update(from: [String: Any]) throws -> Bool
    var id : String { get }
}
```

You have to implement the init and update methods, these handle insert and update operations from Electric, giving you a `[String: Any]` holding the data.

You must also implement `<` to conform to Swift's built in `Comparable` this is not really part of Electric but is used by the publishers to order the list they maintain.

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
    
    // Comparable
    static func <(lhs: Project, rhs: Project) -> Bool {
            return lhs.name < rhs.name
    }
}

```

Next create a `EphemeralShapeManager` in your App giving it the url of your Electric.

And from the `EphemeralShapeManager` create an `EphemeralShapePublisher` for the table you want (optionally with a where clause) and pass it into a View to use.

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
        self.projectsPublisher = self.shapeManager!.publisher(table: "projects")
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
