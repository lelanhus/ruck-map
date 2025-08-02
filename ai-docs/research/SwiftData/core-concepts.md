# SwiftData Core Concepts and Architecture

## Overview

SwiftData is Apple's modern persistence framework introduced in iOS 17, designed as a Swift-first replacement for Core Data. It leverages Swift's modern language features including macros, property wrappers, and strict concurrency.

## Core Components

### 1. Model Definition

SwiftData uses the `@Model` macro to define persistent entities:

```swift
import SwiftData

@Model
final class RuckSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var distance: Double
    var weight: Double
    var calories: Double
    
    @Relationship(deleteRule: .cascade)
    var waypoints: [Waypoint]
    
    @Relationship(inverse: \User.sessions)
    var user: User?
    
    init(startDate: Date, weight: Double) {
        self.id = UUID()
        self.startDate = startDate
        self.weight = weight
        self.distance = 0
        self.calories = 0
        self.waypoints = []
    }
}
```

### 2. ModelContainer

The ModelContainer manages the persistent store:

```swift
let modelContainer = try ModelContainer(
    for: [RuckSession.self, User.self, Waypoint.self],
    configurations: ModelConfiguration(
        schema: Schema([RuckSession.self, User.self, Waypoint.self]),
        url: URL.documentsDirectory.appending(path: "RuckMap.store"),
        cloudKitDatabase: .automatic
    )
)
```

### 3. ModelContext

ModelContext provides the interface for CRUD operations:

```swift
@MainActor
class DataManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save(_ session: RuckSession) throws {
        modelContext.insert(session)
        try modelContext.save()
    }
}
```

## Relationships

### One-to-Many Relationships

```swift
@Model
final class User {
    var name: String
    
    @Relationship(deleteRule: .cascade)
    var sessions: [RuckSession]
}
```

### Many-to-Many Relationships

```swift
@Model
final class Route {
    var name: String
    
    @Relationship(inverse: \Tag.routes)
    var tags: [Tag]
}

@Model
final class Tag {
    var name: String
    var routes: [Route]
}
```

## Query Patterns

### Basic Queries

```swift
@Query(sort: \RuckSession.startDate, order: .reverse)
private var recentSessions: [RuckSession]

@Query(filter: #Predicate<RuckSession> { session in
    session.distance > 5000 && session.calories > 300
})
private var challengingSessions: [RuckSession]
```

### Dynamic Queries

```swift
func fetchSessions(after date: Date) -> [RuckSession] {
    let descriptor = FetchDescriptor<RuckSession>(
        predicate: #Predicate { $0.startDate > date },
        sortBy: [SortDescriptor(\.startDate, order: .reverse)]
    )
    
    return try? modelContext.fetch(descriptor) ?? []
}
```

## Performance Optimization

### 1. Batch Operations

```swift
func batchInsertWaypoints(_ waypoints: [Waypoint]) throws {
    try modelContext.transaction {
        for waypoint in waypoints {
            modelContext.insert(waypoint)
        }
    }
}
```

### 2. Lazy Loading

```swift
@Model
final class RuckSession {
    @Relationship(deleteRule: .cascade)
    var waypoints: [Waypoint] // Loaded on demand
}
```

### 3. Prefetching

```swift
let descriptor = FetchDescriptor<RuckSession>()
descriptor.propertiesToFetch = [\.distance, \.calories]
descriptor.relationshipKeyPathsForPrefetching = [\.waypoints]
```

## Migration Strategies

### Schema Evolution

```swift
enum RuckMapSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [RuckSession.self, User.self]
    }
}

enum RuckMapSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [RuckSession.self, User.self, Route.self]
    }
}
```

### Migration Plan

```swift
enum RuckMapMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RuckMapSchemaV1.self, RuckMapSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: RuckMapSchemaV1.self,
        toVersion: RuckMapSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // Custom migration logic
        }
    )
}
```

## Thread Safety and Concurrency

### Actor Isolation

```swift
@ModelActor
actor DataStore {
    func fetchAllSessions() async throws -> [RuckSession] {
        let descriptor = FetchDescriptor<RuckSession>()
        return try modelContext.fetch(descriptor)
    }
}
```

### Background Processing

```swift
actor BackgroundProcessor {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func processInBackground() async throws {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        
        // Perform background operations
        let sessions = try context.fetch(FetchDescriptor<RuckSession>())
        
        // Process sessions
        
        try context.save()
    }
}
```

## Best Practices

1. **Use Value Types for Properties**: Prefer structs and enums for model properties
2. **Avoid Computed Properties**: They're not persisted and can cause confusion
3. **Handle Optionals Carefully**: SwiftData doesn't support optional relationships well
4. **Use Transactions**: Group related operations in transactions for consistency
5. **Monitor Memory**: Large collections can cause memory issues; use pagination

## Common Pitfalls

1. **Circular References**: Can cause infinite loops during deletion
2. **Missing Inverse Relationships**: Can lead to inconsistent data
3. **Modifying Queries Results**: Always create copies before modification
4. **Ignoring Thread Safety**: Always use appropriate actor isolation
5. **Over-fetching**: Fetch only required properties for better performance

## Resources

- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [WWDC23: Meet SwiftData](https://developer.apple.com/wwdc23/10154)
- [WWDC24: What's new in SwiftData](https://developer.apple.com/wwdc24/10137)