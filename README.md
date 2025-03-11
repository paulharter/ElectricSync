# ElectricSync

A Swift client for ElectricSQL

You can subscribe to Shapes from ElectricSQL using ElectricSync's ShapePublishers.

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

The `PersistentShapePublisher` has the same in memory array but also saves it into SwiftData and keeps track of the Shape's offset so that it can resume from where it left off without relaoding the data and gives you offline reading of the data.

The `PersistentShapePublisher` also has a garbage collector that cleans up old unused shapes.

## Usage

[How to use ephemeral shapes](./Docs/ephemeral.md)

[How to use persistent shapes](./Docs/persistent.md)




