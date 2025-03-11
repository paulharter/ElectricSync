# ElectricSync

A Swift client for ElectricSQL

You can use this library to subscribe to Shapes from ElectricSQL and use them in your SwiftUI projects.

## Requirements

Build your project with xcode as ElectricSync uses Apple's SwiftData for persistence and xcode will pull in the libs and macros.

OS versions:
- iOS 18.0+
- MacOS 15.0+

## Installation

In your project's menu go to `File > Add Package Dependencies...` 

Paste `https://github.com/paulharter/ElectricSync` into the search box.

When it has found this package press `Add Package`

## Usage

Import ElectricSync into your code:

```swift
import ElectricSync
```

Create a shape manager to connect to ElectricSQL

```swift
let shapeManager = EphemeralShapeManager(dbUrl: "http://127.0.0.1:3000")
```

Then for each shape you want create a publisher, optionally with `where` and/or `sort`:

```
let projectsPublisher = shapeManager.publisher(table: "projects", where: "status='active'", sort:  { one, two in
            return one.name > two.name
        })
```

Then use this publisher in your views

```
List {
    ForEach(projectsPublisher.items) { project in
        Text(project.name)
    }
}
```

## Ephemeral and persistent shapes

There are two flavours of `ShapePublisher` that both read from a `ShapeStream`

- `EphemeralShapePublisher` 
- `PersistentShapePublisher`

The Ephemeral version is more light weight and less resource hungry, but the persistent one gives you offline reads of cached data.


The `EphemeralShapePublisher` has an in-memory array called `items` which is kept in sync with your shape for the lifetime of the publisher. 

```
public class EphemeralShapePublisher<T: ElectricModel >: ObservableObject, ShapeStreamSubscriber{

    @Published public var items: [T] = []
    
    ...
}
```

The `PersistentShapePublisher` has the same in memory array but also saves it into SwiftData and keeps track of the Shape's offset so that it can resume from where it left off without reloading the data and gives you offline reading of the data.

The `PersistentShapePublisher` also has a garbage collector that cleans up old unused shapes.

## Detailed Usage

[How to use ephemeral shapes](./Docs/ephemeral.md)

[How to use persistent shapes](./Docs/persistent.md)




