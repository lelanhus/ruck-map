import XCTest
import CoreLocation
import SwiftData
@testable import RuckMap

final class CompressionIntegrationTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var sessionManager: SessionManager!
    private var trackCompressor: TrackCompressor!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container
        let schema = Schema([
            RuckSession.self,
            LocationPoint.self,
            TerrainSegment.self,
            WeatherConditions.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        
        sessionManager = SessionManager(modelContainer: modelContainer)
        trackCompressor = TrackCompressor()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        sessionManager = nil
        trackCompressor = nil
        try await super.tearDown()
    }
    
    func testEndToEndCompressionWorkflow() async throws {
        // Create a test session with many points
        let session = RuckSession()
        session.loadWeight = 20
        
        // Generate a realistic GPS track (2km walk with some curves)
        let baseCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        var locations: [CLLocation] = []
        
        // Create 1000 points along a path
        for i in 0..<1000 {
            let progress = Double(i) / 1000.0
            
            // Add some curves and elevation changes
            let lat = baseCoordinate.latitude + progress * 0.018 + sin(progress * 10) * 0.001
            let lon = baseCoordinate.longitude + progress * 0.01 + cos(progress * 8) * 0.001
            let elevation = 100 + sin(progress * 5) * 20 // Vary elevation
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: elevation,
                horizontalAccuracy: 5,
                verticalAccuracy: 10,
                timestamp: Date().addingTimeInterval(Double(i) * 2) // 2 seconds apart
            )
            locations.append(location)
        }
        
        // Convert to LocationPoints and save session
        for (index, location) in locations.enumerated() {
            let point = LocationPoint(from: location)
            point.compressionIndex = index // Store original index
            session.locationPoints.append(point)
        }
        
        // Save session
        let savedSession = try await sessionManager.saveSession(session)
        XCTAssertNotNil(savedSession)
        XCTAssertEqual(savedSession.locationPoints.count, 1000)
        
        // Compress the track
        let compressed = await trackCompressor.compressTrack(locations, epsilon: 5.0)
        
        // Verify compression
        XCTAssertLessThan(compressed.count, locations.count)
        XCTAssertGreaterThan(compressed.count, 10) // Should keep at least some points
        
        // Print compression statistics
        let compressionRatio = Double(compressed.count) / Double(locations.count)
        print("Compression ratio: \(compressionRatio * 100)%")
        print("Original points: \(locations.count)")
        print("Compressed points: \(compressed.count)")
        
        // Verify key points are preserved
        XCTAssertEqual(compressed.first?.coordinate.latitude, locations.first?.coordinate.latitude)
        XCTAssertEqual(compressed.last?.coordinate.latitude, locations.last?.coordinate.latitude)
        
        // Update session with compressed points
        session.locationPoints.removeAll()
        for (index, location) in compressed.enumerated() {
            let point = LocationPoint(from: location)
            point.compressionIndex = index
            point.compressedTimestamp = Date()
            session.locationPoints.append(point)
        }
        
        // Save compressed session
        let compressedSession = try await sessionManager.saveSession(session)
        XCTAssertEqual(compressedSession.locationPoints.count, compressed.count)
        
        // Export to GPX
        let exportManager = ExportManager()
        let gpxURL = try await exportManager.exportToGPX(session: compressedSession)
        XCTAssertNotNil(gpxURL)
        
        // Verify GPX file exists and has content
        let gpxData = try Data(contentsOf: gpxURL)
        XCTAssertGreaterThan(gpxData.count, 1000) // Should have substantial content
        
        // Export to CSV
        let csvURL = try await exportManager.exportToCSV(session: compressedSession)
        XCTAssertNotNil(csvURL)
        
        // Verify CSV has proper headers and data
        let csvContent = try String(contentsOf: csvURL)
        XCTAssertTrue(csvContent.contains("timestamp"))
        XCTAssertTrue(csvContent.contains("latitude"))
        XCTAssertTrue(csvContent.contains("elevation"))
        
        // Clean up
        try FileManager.default.removeItem(at: gpxURL)
        try FileManager.default.removeItem(at: csvURL)
    }
    
    func testCompressionPerformance() async throws {
        // Generate large dataset
        var locations: [CLLocation] = []
        let baseCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        for i in 0..<10000 {
            let progress = Double(i) / 10000.0
            let lat = baseCoordinate.latitude + progress * 0.1
            let lon = baseCoordinate.longitude + progress * 0.1
            
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: 100 + Double(i % 100),
                horizontalAccuracy: 5,
                verticalAccuracy: 10,
                timestamp: Date()
            )
            locations.append(location)
        }
        
        // Measure compression time
        let startTime = Date()
        let compressed = await trackCompressor.compressTrack(locations, epsilon: 10.0)
        let compressionTime = Date().timeIntervalSince(startTime)
        
        print("Compressed 10,000 points in \(compressionTime) seconds")
        print("Result: \(compressed.count) points")
        
        // Should complete quickly
        XCTAssertLessThan(compressionTime, 1.0) // Should take less than 1 second
        XCTAssertLessThan(compressed.count, 1000) // Should compress significantly
    }
    
    func testAutoSaveAndRestore() async throws {
        // Create an active session
        let session = RuckSession()
        session.loadWeight = 30
        session.startDate = Date()
        
        // Add some location points
        for i in 0..<100 {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 37.7749 + Double(i) * 0.0001,
                    longitude: -122.4194
                ),
                altitude: 100,
                horizontalAccuracy: 5,
                verticalAccuracy: 10,
                timestamp: Date()
            )
            let point = LocationPoint(from: location)
            session.locationPoints.append(point)
        }
        
        // Save as active session
        let saved = try await sessionManager.saveSession(session)
        
        // Restore active sessions
        let activeSessions = await sessionManager.restoreIncompleteSessions()
        XCTAssertEqual(activeSessions.count, 1)
        XCTAssertEqual(activeSessions.first?.id, saved.id)
        XCTAssertEqual(activeSessions.first?.locationPoints.count, 100)
    }
}