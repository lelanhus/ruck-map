# SwiftData CloudKit Integration

## Overview

SwiftData provides automatic CloudKit synchronization, enabling seamless data sync across user devices. This document covers best practices, implementation strategies, and common patterns for production apps.

## Basic Setup

### 1. Enable CloudKit Capability

In Xcode:
1. Select your project target
2. Go to "Signing & Capabilities"
3. Add "CloudKit" capability
4. Enable "CloudKit Console" and "Remote Notifications"

### 2. Configure ModelContainer

```swift
let modelConfiguration = ModelConfiguration(
    schema: Schema([
        RuckSession.self,
        User.self,
        Route.self,
        Waypoint.self
    ]),
    url: URL.documentsDirectory.appending(path: "RuckMap.store"),
    cloudKitDatabase: .automatic // Enables CloudKit sync
)

let modelContainer = try ModelContainer(
    for: [RuckSession.self, User.self, Route.self, Waypoint.self],
    configurations: modelConfiguration
)
```

## Sync Strategies

### 1. Automatic Sync (Default)

```swift
// SwiftData handles sync automatically
modelConfiguration.cloudKitDatabase = .automatic
```

### 2. Private Database Only

```swift
modelConfiguration.cloudKitDatabase = .private
```

### 3. Hybrid Approach (Local + Cloud)

```swift
// Local-only configuration
let localConfig = ModelConfiguration(
    schema: Schema([CachedData.self]),
    url: URL.documentsDirectory.appending(path: "Cache.store"),
    cloudKitDatabase: .none
)

// Cloud-synced configuration
let cloudConfig = ModelConfiguration(
    schema: Schema([RuckSession.self, User.self]),
    url: URL.documentsDirectory.appending(path: "Cloud.store"),
    cloudKitDatabase: .automatic
)

let container = try ModelContainer(
    for: [RuckSession.self, User.self, CachedData.self],
    configurations: localConfig, cloudConfig
)
```

## Conflict Resolution

### 1. Last Writer Wins (Default)

SwiftData uses CloudKit's default conflict resolution:

```swift
// No additional code needed - CloudKit handles automatically
```

### 2. Custom Conflict Resolution

```swift
@Model
final class RuckSession {
    var id: UUID
    var modifiedDate: Date
    var version: Int
    
    // Custom merge logic
    func merge(with remote: RuckSession) -> RuckSession {
        if remote.modifiedDate > self.modifiedDate {
            return remote
        } else if remote.modifiedDate < self.modifiedDate {
            return self
        } else {
            // Same modification time - merge fields
            return mergeFields(local: self, remote: remote)
        }
    }
}
```

### 3. Handling Sync Notifications

```swift
class SyncMonitor: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncNotification),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }
    
    @objc private func handleSyncNotification(_ notification: Notification) {
        Task { @MainActor in
            syncStatus = .syncing
            // Process changes
            syncStatus = .completed
        }
    }
}
```

## Offline-First Architecture

### 1. Queue Operations When Offline

```swift
actor OfflineQueue {
    private var pendingOperations: [Operation] = []
    private let modelContainer: ModelContainer
    
    func enqueue(_ operation: Operation) {
        pendingOperations.append(operation)
    }
    
    func processPendingOperations() async throws {
        guard NetworkMonitor.shared.isConnected else { return }
        
        let context = ModelContext(modelContainer)
        
        for operation in pendingOperations {
            try await operation.execute(in: context)
        }
        
        try context.save()
        pendingOperations.removeAll()
    }
}
```

### 2. Network Monitoring

```swift
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
```

### 3. Sync State Management

```swift
@Model
final class RuckSession {
    var id: UUID
    var syncStatus: SyncStatus = .pending
    var lastSyncAttempt: Date?
    var syncError: String?
    
    enum SyncStatus: String, Codable {
        case pending
        case syncing
        case synced
        case failed
    }
}
```

## Performance Optimization

### 1. Batch Sync Operations

```swift
class BatchSyncManager {
    private let modelContainer: ModelContainer
    private var syncTimer: Timer?
    private var pendingChanges: Set<UUID> = []
    
    func trackChange(for id: UUID) {
        pendingChanges.insert(id)
        scheduleBatchSync()
    }
    
    private func scheduleBatchSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: false
        ) { _ in
            Task {
                await self.performBatchSync()
            }
        }
    }
    
    private func performBatchSync() async {
        // Batch sync implementation
    }
}
```

### 2. Selective Sync

```swift
@Model
final class RuckSession {
    var id: UUID
    var isLocalOnly: Bool = false // Exclude from sync
    
    @Transient
    var largeImageData: Data? // Not synced
}
```

### 3. Progressive Sync

```swift
class ProgressiveSyncManager {
    func syncInPriority() async throws {
        // 1. Sync critical data first
        try await syncRecentSessions()
        
        // 2. Sync user preferences
        try await syncUserSettings()
        
        // 3. Sync historical data
        try await syncHistoricalData()
        
        // 4. Sync media/attachments
        try await syncMediaContent()
    }
}
```

## Error Handling

### 1. Common CloudKit Errors

```swift
enum CloudKitError: Error {
    case quotaExceeded
    case networkUnavailable
    case serverRejected
    case conflictRetryLater
    case userNotAuthenticated
}

func handleCloudKitError(_ error: Error) -> CloudKitError? {
    guard let ckError = error as? CKError else { return nil }
    
    switch ckError.code {
    case .quotaExceeded:
        return .quotaExceeded
    case .networkUnavailable, .networkFailure:
        return .networkUnavailable
    case .serverRejectedRequest:
        return .serverRejected
    case .requestRateLimited:
        return .conflictRetryLater
    case .notAuthenticated:
        return .userNotAuthenticated
    default:
        return nil
    }
}
```

### 2. Retry Logic

```swift
actor RetryManager {
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 2.0
    
    func performWithRetry<T>(
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if let ckError = error as? CKError {
                    if ckError.code == .requestRateLimited,
                       let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                        continue
                    }
                }
                
                let delay = baseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? CloudKitError.serverRejected
    }
}
```

## Security Considerations

### 1. Data Encryption

```swift
@Model
final class SensitiveData {
    var id: UUID
    
    private var encryptedContent: Data
    
    @Transient
    var content: String {
        get {
            // Decrypt content
            return decrypt(encryptedContent)
        }
        set {
            // Encrypt before storing
            encryptedContent = encrypt(newValue)
        }
    }
}
```

### 2. User Privacy

```swift
extension RuckSession {
    var shareableData: ShareableRuckSession {
        ShareableRuckSession(
            distance: distance,
            duration: duration,
            // Exclude precise location data
            generalArea: generalizeLocation(from: waypoints)
        )
    }
}
```

## Testing CloudKit Sync

### 1. Unit Testing with Mock Container

```swift
class MockCloudKitContainer: ModelContainer {
    var simulateError: Error?
    var syncDelay: TimeInterval = 0
    
    override func save() throws {
        if let error = simulateError {
            throw error
        }
        
        Thread.sleep(forTimeInterval: syncDelay)
        try super.save()
    }
}
```

### 2. Integration Testing

```swift
class CloudKitIntegrationTests: XCTestCase {
    func testDataSyncBetweenDevices() async throws {
        // Create two containers simulating different devices
        let device1 = try ModelContainer(for: RuckSession.self)
        let device2 = try ModelContainer(for: RuckSession.self)
        
        // Add data to device1
        let context1 = ModelContext(device1)
        let session = RuckSession(startDate: Date(), weight: 35)
        context1.insert(session)
        try context1.save()
        
        // Wait for sync
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Verify data appears in device2
        let context2 = ModelContext(device2)
        let sessions = try context2.fetch(FetchDescriptor<RuckSession>())
        XCTAssertEqual(sessions.count, 1)
    }
}
```

## Best Practices

1. **Design for Eventual Consistency**: Don't assume immediate sync
2. **Handle Offline Gracefully**: Queue operations and sync when online
3. **Minimize Sync Data**: Use @Transient for local-only properties
4. **Monitor Sync Status**: Provide user feedback on sync state
5. **Test Edge Cases**: Network failures, conflicts, quota limits
6. **Respect User Privacy**: Don't sync sensitive data without consent
7. **Optimize for Battery**: Batch sync operations when possible

## Common Issues and Solutions

### Issue: Slow Initial Sync
**Solution**: Implement progressive sync, prioritizing recent data

### Issue: Quota Exceeded
**Solution**: Implement data retention policies and cleanup old data

### Issue: Sync Conflicts
**Solution**: Implement proper conflict resolution with user feedback

### Issue: Authentication Failures
**Solution**: Guide users to sign into iCloud in Settings

## Resources

- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Best Practices](https://developer.apple.com/documentation/cloudkit/designing_and_creating_a_cloudkit_database)
- [WWDC: Sync SwiftData with CloudKit](https://developer.apple.com/videos/play/wwdc2023/10154/)