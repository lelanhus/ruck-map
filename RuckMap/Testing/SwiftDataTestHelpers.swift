import Foundation
import SwiftData
import Testing

// MARK: - Test Helpers for SwiftData
struct SwiftDataTestHelpers {
    
    // MARK: - Test Container Creation
    static func createTestContainer(name: String = #function) throws -> ModelContainer {
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            url: URL.temporaryDirectory.appending(path: "\(name).store"),
            cloudKitDatabase: .none // Disable CloudKit for testing
        )
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    static func createInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    // MARK: - Sample Data Creation
    static func createSampleRuckSession(
        startDate: Date = Date(),
        loadWeight: Double = 35.0,
        isCompleted: Bool = false
    ) throws -> RuckSession {
        let session = try RuckSession(loadWeight: loadWeight)
        session.startDate = startDate
        
        if isCompleted {
            session.endDate = startDate.addingTimeInterval(3600) // 1 hour
            session.totalDistance = 5000 // 5km
            session.totalDuration = 3600
            session.totalCalories = 450
            session.averagePace = 12.0 // 12 min/km
            session.elevationGain = 100
            session.elevationLoss = 95
            session.rpe = 7
        }
        
        return session
    }
    
    static func createSampleLocationPoints(count: Int = 10) -> [LocationPoint] {
        var points: [LocationPoint] = []
        let baseLatitude = 37.7749 // San Francisco
        let baseLongitude = -122.4194
        
        for i in 0..<count {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(TimeInterval(i * 60)), // Every minute
                latitude: baseLatitude + Double(i) * 0.001,
                longitude: baseLongitude + Double(i) * 0.001,
                altitude: 100.0 + Double(i) * 2.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 8.0,
                speed: 1.4, // ~5 km/h
                course: 45.0,
                isKeyPoint: i % 5 == 0 // Every 5th point is a key point
            )
            points.append(point)
        }
        
        return points
    }
    
    static func createSampleTerrainSegment(
        startTime: Date = Date(),
        duration: TimeInterval = 1800, // 30 minutes
        terrainType: TerrainType = .trail
    ) -> TerrainSegment {
        return TerrainSegment(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(duration),
            terrainType: terrainType,
            grade: 5.0, // 5% grade
            confidence: 0.8,
            isManuallySet: false
        )
    }
    
    static func createSampleWeatherConditions(
        timestamp: Date = Date()
    ) -> WeatherConditions {
        return WeatherConditions(
            timestamp: timestamp,
            temperature: 18.0, // 18°C
            humidity: 65.0,
            windSpeed: 5.0,
            windDirection: 180.0,
            precipitation: 0.0,
            pressure: 1013.25
        )
    }
    
    // MARK: - Test Assertions
    static func assertValidRuckSession(_ session: RuckSession) {
        #expect(session.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(session.startDate <= Date())
        #expect(session.loadWeight > 0)
        #expect(session.loadWeight <= 200)
        #expect(session.totalDistance >= 0)
        #expect(session.totalCalories >= 0)
        #expect(session.elevationGain >= 0)
        #expect(session.elevationLoss >= 0)
        
        if let rpe = session.rpe {
            #expect(rpe >= 1 && rpe <= 10)
        }
        
        if let endDate = session.endDate {
            #expect(endDate >= session.startDate)
        }
    }
    
    static func assertValidLocationPoint(_ point: LocationPoint) {
        #expect(point.latitude >= -90 && point.latitude <= 90)
        #expect(point.longitude >= -180 && point.longitude <= 180)
        #expect(point.horizontalAccuracy > 0)
        #expect(point.speed >= 0)
        
        if point.course >= 0 {
            #expect(point.course < 360)
        }
    }
    
    static func assertValidTerrainSegment(_ segment: TerrainSegment) {
        #expect(segment.endTime > segment.startTime)
        #expect(segment.confidence >= 0 && segment.confidence <= 1)
        #expect(segment.grade >= -100) // Allow steep downhills
    }
    
    // MARK: - Performance Testing Helpers
    static func measureTime<T>(
        operation: () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        print("Operation completed in \(String(format: "%.3f", duration))s at \(file):\(line)")
        
        return (result, duration)
    }
    
    static func createLargeDataset(
        sessionCount: Int = 100,
        pointsPerSession: Int = 100
    ) async throws -> [RuckSession] {
        var sessions: [RuckSession] = []
        let baseDate = Date().addingTimeInterval(-TimeInterval(sessionCount * 24 * 3600)) // Start from sessionCount days ago
        
        for i in 0..<sessionCount {
            let session = try createSampleRuckSession(
                startDate: baseDate.addingTimeInterval(TimeInterval(i * 24 * 3600)),
                loadWeight: Double.random(in: 20...50),
                isCompleted: true
            )
            
            // Add location points
            let points = createSampleLocationPoints(count: pointsPerSession)
            session.locationPoints = points
            
            // Add terrain segment
            let terrain = createSampleTerrainSegment(
                startTime: session.startDate,
                terrainType: TerrainType.allCases.randomElement() ?? .trail
            )
            session.terrainSegments = [terrain]
            
            // Add weather
            let weather = createSampleWeatherConditions(timestamp: session.startDate)
            session.weatherConditions = weather
            
            sessions.append(session)
        }
        
        return sessions
    }
}

// MARK: - Test Suite Base Class
@MainActor
class SwiftDataTestSuite {
    var container: ModelContainer!
    var context: ModelContext!
    var repository: SwiftDataRuckSessionRepository!
    
    func setUp() async throws {
        container = try SwiftDataTestHelpers.createInMemoryContainer()
        context = ModelContext(container)
        repository = SwiftDataRuckSessionRepository(modelContainer: container)
    }
    
    func tearDown() async {
        container = nil
        context = nil
        repository = nil
    }
    
    func insertSampleSession() async throws -> RuckSession {
        let session = try SwiftDataTestHelpers.createSampleRuckSession(isCompleted: true)
        context.insert(session)
        try context.save()
        return session
    }
}

// MARK: - CloudKit Testing Helpers
struct CloudKitTestHelpers {
    
    static func createCloudKitTestContainer() throws -> ModelContainer {
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            url: URL.temporaryDirectory.appending(path: "CloudKitTest.store"),
            cloudKitDatabase: .private // Use private database for testing
        )
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    static func simulateOfflineMode() {
        // Disable network connectivity for testing offline scenarios
        // This would typically involve mocking network layers
    }
    
    static func simulateSyncConflict() {
        // Create scenarios where data conflicts occur
        // This would involve creating identical records with different modifications
    }
}

// MARK: - Benchmark Tests
struct SwiftDataBenchmarks {
    
    static func benchmarkLargeDataInsertion(
        sessionCount: Int = 1000,
        pointsPerSession: Int = 100
    ) async throws -> TimeInterval {
        let container = try SwiftDataTestHelpers.createInMemoryContainer()
        let context = ModelContext(container)
        
        let (_, duration) = try await SwiftDataTestHelpers.measureTime {
            let sessions = try await SwiftDataTestHelpers.createLargeDataset(
                sessionCount: sessionCount,
                pointsPerSession: pointsPerSession
            )
            
            for session in sessions {
                context.insert(session)
            }
            
            try context.save()
        }
        
        return duration
    }
    
    static func benchmarkQueryPerformance() async throws -> TimeInterval {
        let container = try SwiftDataTestHelpers.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataRuckSessionRepository(modelContainer: container)
        
        // Insert test data
        let sessions = try await SwiftDataTestHelpers.createLargeDataset(sessionCount: 500)
        for session in sessions {
            context.insert(session)
        }
        try context.save()
        
        // Benchmark query
        let (_, duration) = try await SwiftDataTestHelpers.measureTime {
            _ = try await repository.fetchSessions(
                after: Date().addingTimeInterval(-30 * 24 * 3600), // Last 30 days
                minDistance: 3000,
                minWeight: 25
            )
        }
        
        return duration
    }
}