
# Persistent Shapes


The `PersistentShapePublisher" publishes the same in-memory array as the ephemeral one but also saves it into SwiftData and keeps track of the Shape's offset so that it can resume from where it left off.

## Usage

Define your object type, it should be a class that uses the SwiftData @Model macro and that conform to the 'PersistentElectricModel' protocol. 
This the same as the `ElectricModel` protocol but with the additional shapeHashes that are used by the Garbage Collector.

```swift
public protocol ElectricModel: Hashable & Identifiable{
    init(from: [String: Any]) throws
    mutating func update(from: [String: Any]) throws -> Bool
    var id : String { get }
}

public protocol PersistentElectricModel: ElectricModel{
    var shapeHashes :  [Int: Int] { get set }
}
```

You have to implement the init and update methods, these handle insert and update operations from Electric, giving you a `[String: Any]` holding the data.

for example:

```
@Model
class Project: PersistentElectricModel{

    var id: String
    var name: String
    var shapeHashes: [Int: Int] = [:]
    
    required init(from: [String: Any]) throws {
        guard let id = from["id"] as? String else { throw DecodeError.runtimeError("id is missing")}
        guard let name = from["name"] as? String else { throw DecodeError.runtimeError("name is missing")}
        self.id = id
        self.name = name
    }

    func update(from: [String: Any]) throws -> Bool {
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

You then need to create a SwiftData `ModelContainer` for the persistence, passing in your models and the ElectricSync built in model `ShapeRecord`:

```swift
let container: ModelContainer = try ModelContainer(for:
                                                    Project.self,
                                                    ShapeRecord.self)
```

And then use this to create a `PersistentShapeManager` in your App giving it the url of your Electric.

You can also optionally modify the default behaviour of the ElectricSync `GarbageCollector` by giving values for 

And from the `PersistentShapeManager` create an `PersistentShapePublisher` for the table you want (optionally with a where clause and sort function) and pass it into a View to use.

You can pass it the `PersistentShapeManager` down to other views as an `environmentObject` so they can create other `PersistentShapePublisher` as needed

```swift
import SwiftUI
import SwiftData
import ElectricSync

@main
struct MyApp: App {
    
    var shapeManager: PersistentShapeManager?
    var projectsPublisher: PersistentShapePublisher<Project>?
    var container: ModelContainer?

    init() {
        
        do {
            self.container = try ModelContainer(for:
                                                Project.self,
                                                ShapeRecord.self)
            
            self.shapeManager = PersistentShapeManager(for: Project.self,
                                                       context: container!.mainContext,
                                                       dbUrl: "http://127.0.0.1:3000",
                                                       bytesLimit: 1024 * 1024 * 256, // 256MB
                                                       timeLimit: 60 * 60 * 24 * 4) // four days
                                                       
            self.projectsPublisher = try self.shapeManager!.publisher(table: "projects")
            
        } catch let err{
            print("init failed: \(err)")
        }
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

and then use the `PersistentShapePublisher` in a View:

```swift
import SwiftUI
import ElectricSync

struct ContentView: View {
    @StateObject var projectsPublisher: PersistentShapePublisher<Project>

    var body: some View {
        List {
            ForEach(projectsPublisher.items) { project in
                Text(project.name)
            }
        }
    }
}
```
