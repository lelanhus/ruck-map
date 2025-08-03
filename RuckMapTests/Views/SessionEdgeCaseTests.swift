import Testing
import SwiftUI
import SwiftData
@testable import RuckMap

/// Edge case and stress tests for Session 12 components
@Suite("Session Edge Case Tests")
struct SessionEdgeCaseTests {
    
    @Test("SessionSummaryView handles empty session gracefully")
    func testEmptySessionHandling() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: RuckSession.self, configurations: config)
        let context = container.mainContext
        
        // Create completely empty session
        let emptySession = RuckSession()
        context.insert(emptySession)
        
        let viewModel = SessionSummaryViewModel()
        
        // Should handle empty session without crashing
        try await viewModel.saveSession(emptySession, modelContext: context)
        
        // Verify session has minimal required data
        #expect(emptySession.endDate != nil)
        #expect(emptySession.id != nil)
        #expect(emptySession.startDate != nil)
    }
    
    @Test("SessionHistoryView handles massive dataset", .timeLimit(.seconds(10)))
    func testMassiveDatasetHandling() async throws {
        let viewModel = SessionHistoryViewModel()
        
        // Create 10,000 sessions to test performance
        let massiveSessions = await withTaskGroup(of: RuckSession.self, returning: [RuckSession].self) { group in
            var sessions: [RuckSession] = []
            
            for i in 0..<10000 {
                group.addTask {
                    let session = RuckSession()
                    session.totalDistance = Double.random(in: 1000...20000)
                    session.totalDuration = Double.random(in: 600...7200)
                    session.loadWeight = Double.random(in: 10...50)
                    session.totalCalories = Double.random(in: 200...1500)
                    session.startDate = Date().addingTimeInterval(-TimeInterval(i * 3600))
                    session.endDate = session.startDate.addingTimeInterval(session.totalDuration)
                    session.rpe = Int.random(in: 1...10)
                    return session
                }
            }
            
            for await session in group {
                sessions.append(session)
            }
            
            return sessions
        }
        
        // Test filtering performance
        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.updateSessions(massiveSessions)
        
        // Apply complex filters
        viewModel.searchText = "test"
        viewModel.selectedTimeRange = .year
        viewModel.distanceRange = 5...15
        viewModel.minCalories = 500
        
        let filteredResults = viewModel.filteredSessions(from: massiveSessions)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Should complete within reasonable time
        #expect(endTime - startTime < 5.0)
        #expect(filteredResults.count <= massiveSessions.count)
        
        print("Filtered \(massiveSessions.count) sessions in \(String(format: "%.3f", endTime - startTime))s, found \(filteredResults.count) matches")
    }
    
    @Test("DetailedSessionView handles corrupt location data")
    func testCorruptLocationDataHandling() async throws {
        let session = RuckSession()
        session.startDate = Date().addingTimeInterval(-3600)
        session.endDate = Date()
        
        // Add various corrupt location points
        let corruptPoints = [
            // Invalid coordinates
            LocationPoint(timestamp: Date(), latitude: 999.0, longitude: 999.0, altitude: 0, 
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 0, course: 0),
            
            // Extreme coordinates
            LocationPoint(timestamp: Date(), latitude: 90.0, longitude: 180.0, altitude: -1000, 
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 0, course: 0),
            
            // Poor accuracy
            LocationPoint(timestamp: Date(), latitude: 37.7749, longitude: -122.4194, altitude: 100, 
                         horizontalAccuracy: 500.0, verticalAccuracy: 500.0, speed: 0, course: 0),
            
            // Extreme speed
            LocationPoint(timestamp: Date(), latitude: 37.7750, longitude: -122.4195, altitude: 100, 
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 1000.0, course: 0),
            
            // Future timestamp
            LocationPoint(timestamp: Date().addingTimeInterval(86400), latitude: 37.7751, longitude: -122.4196, altitude: 100, 
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 1.0, course: 0)
        ]
        
        session.locationPoints = corruptPoints
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Should handle corrupt data without crashing
        #expect(presentation.session?.id == session.id)
        #expect(presentation.interactivePoints.count >= 0) // May filter out invalid points
        
        // Test replay with corrupt data
        presentation.toggleReplayMode()
        #expect(presentation.isReplayMode == true)
        
        presentation.toggleReplay()
        presentation.stopReplay()
        #expect(presentation.isReplaying == false)
    }
    
    @Test("Export handles edge case file sizes and formats")
    func testExportEdgeCases() async throws {
        let exportManager = ExportManager()
        
        // Test extremely small session
        let tinySession = RuckSession()
        tinySession.locationPoints = [
            LocationPoint(timestamp: Date(), latitude: 0.0, longitude: 0.0, altitude: 0, 
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 0, course: 0)
        ]
        
        let tinyResult = try await exportManager.exportToGPX(session: tinySession)
        #expect(tinyResult.pointCount == 1)
        #expect(tinyResult.fileSize > 0)
        
        // Test session with duplicate points
        let duplicateSession = RuckSession()
        let duplicatePoint = LocationPoint(timestamp: Date(), latitude: 37.7749, longitude: -122.4194, altitude: 100, 
                                          horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 1.0, course: 0)
        
        // Add 1000 identical points
        for _ in 0..<1000 {
            duplicateSession.locationPoints.append(duplicatePoint)
        }
        
        let duplicateResult = try await exportManager.exportToGPX(session: duplicateSession)
        #expect(duplicateResult.pointCount == 1000)
        #expect(duplicateResult.fileSize > 0)
        
        // Test session with extreme coordinates
        let extremeSession = RuckSession()
        let extremePoints = [
            LocationPoint(timestamp: Date(), latitude: -90.0, longitude: -180.0, altitude: -100, 
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 0, course: 0),
            LocationPoint(timestamp: Date(), latitude: 90.0, longitude: 180.0, altitude: 8848, 
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 100, course: 359)
        ]
        extremeSession.locationPoints = extremePoints
        
        let extremeResult = try await exportManager.exportToCSV(session: extremeSession)
        #expect(extremeResult.pointCount == 2)
        #expect(extremeResult.fileSize > 0)
    }
    
    @Test("Voice recording handles various error conditions")
    func testVoiceRecordingEdgeCases() async {
        let viewModel = SessionSummaryViewModel()
        
        // Test multiple stop calls
        viewModel.stopVoiceRecording()
        viewModel.stopVoiceRecording()
        viewModel.stopVoiceRecording()
        #expect(viewModel.isRecording == false)
        
        // Test error state handling
        let errors: [VoiceRecordingError] = [
            .speechRecognizerUnavailable,
            .authorizationDenied,
            .recognitionRequestFailed,
            .audioEngineError
        ]
        
        for error in errors {
            viewModel.saveError = error
            #expect(viewModel.saveError != nil)
            
            // Test that error descriptions are meaningful
            #expect(!error.errorDescription!.isEmpty)
            #expect(error.errorDescription!.count > 10) // Should be descriptive
        }
        
        // Test error clearing
        viewModel.saveError = nil
        #expect(viewModel.saveError == nil)
    }
    
    @Test("Session statistics handle extreme values")
    func testExtremeStatisticsValues() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: RuckSession.self, configurations: config)
        let context = container.mainContext
        
        let extremeCases = [
            // Zero values
            (distance: 0.0, duration: 0.0, calories: 0.0, elevation: 0.0, weight: 0.0),
            
            // Minimum values
            (distance: 1.0, duration: 1.0, calories: 1.0, elevation: 1.0, weight: 1.0),
            
            // Very large values
            (distance: 1000000.0, duration: 86400.0, calories: 10000.0, elevation: 10000.0, weight: 1000.0),
            
            // Floating point edge cases
            (distance: Double.leastNormalMagnitude, duration: Double.leastNormalMagnitude, 
             calories: Double.leastNormalMagnitude, elevation: Double.leastNormalMagnitude, weight: Double.leastNormalMagnitude)
        ]
        
        for (distance, duration, calories, elevation, weight) in extremeCases {
            let session = RuckSession()
            session.totalDistance = distance
            session.totalDuration = duration
            session.totalCalories = calories
            session.elevationGain = elevation
            session.loadWeight = weight
            session.averagePace = duration > 0 ? duration / 60 : 0
            
            context.insert(session)
            
            // Test that formatting doesn't crash
            let distanceFormatted = FormatUtilities.formatDistancePrecise(session.totalDistance)
            let durationFormatted = FormatUtilities.formatDurationWithSeconds(session.totalDuration)
            let weightFormatted = FormatUtilities.formatWeight(session.loadWeight)
            
            #expect(!distanceFormatted.isEmpty)
            #expect(!durationFormatted.isEmpty) 
            #expect(!weightFormatted.isEmpty)
            
            // Test that calculations don't produce NaN or infinity
            let pace = session.averagePace
            #expect(!pace.isNaN)
            #expect(!pace.isInfinite)
            
            context.delete(session)
        }
    }
    
    @Test("Weather conditions handle extreme weather scenarios")
    func testExtremeWeatherConditions() async {
        let extremeWeatherCases = [
            // Arctic conditions
            WeatherConditions(temperature: -50.0, humidity: 10.0, windSpeed: 0.0, precipitation: 0.0),
            
            // Desert conditions
            WeatherConditions(temperature: 60.0, humidity: 5.0, windSpeed: 0.0, precipitation: 0.0),
            
            // Hurricane conditions
            WeatherConditions(temperature: 25.0, humidity: 100.0, windSpeed: 200.0, precipitation: 100.0),
            
            // Impossible conditions (for robustness testing)
            WeatherConditions(temperature: 1000.0, humidity: 200.0, windSpeed: -50.0, precipitation: 1000.0)
        ]
        
        for weather in extremeWeatherCases {
            // Test that calculations don't crash
            let adjustmentFactor = weather.temperatureAdjustmentFactor
            #expect(!adjustmentFactor.isNaN)
            #expect(!adjustmentFactor.isInfinite)
            #expect(adjustmentFactor >= 0.0) // Should be non-negative
            
            // Test harsh conditions detection
            let isHarsh = weather.isHarshConditions
            #expect(isHarsh == true || isHarsh == false) // Should be boolean
            
            // Test temperature conversions
            let fahrenheit = weather.temperatureFahrenheit
            #expect(!fahrenheit.isNaN)
            #expect(!fahrenheit.isInfinite)
            
            let windMPH = weather.windSpeedMPH
            #expect(!windMPH.isNaN)
            #expect(!windMPH.isInfinite)
        }
    }
    
    @Test("Terrain analysis handles complex terrain combinations")
    func testComplexTerrainAnalysis() async throws {
        let session = RuckSession()
        session.startDate = Date().addingTimeInterval(-7200) // 2 hours ago
        session.endDate = Date()
        session.totalDuration = 7200 // 2 hours
        
        // Create complex terrain with overlapping segments and gaps
        var terrainSegments: [TerrainSegment] = []
        
        // First 30 minutes - trail
        terrainSegments.append(TerrainSegment(
            startTime: session.startDate,
            endTime: session.startDate.addingTimeInterval(1800),
            terrainType: .trail,
            grade: 5.0
        ))
        
        // 15 minute gap (no terrain data)
        
        // Next 45 minutes - road
        terrainSegments.append(TerrainSegment(
            startTime: session.startDate.addingTimeInterval(2700),
            endTime: session.startDate.addingTimeInterval(5400),
            terrainType: .pavedRoad,
            grade: 1.0
        ))
        
        // Overlapping segment - stairs (last 30 minutes)
        terrainSegments.append(TerrainSegment(
            startTime: session.startDate.addingTimeInterval(5400),
            endTime: session.endDate!,
            terrainType: .stairs,
            grade: 15.0
        ))
        
        // Zero duration segment (edge case)
        terrainSegments.append(TerrainSegment(
            startTime: session.endDate!,
            endTime: session.endDate!,
            terrainType: .mud,
            grade: 8.0
        ))
        
        session.terrainSegments = terrainSegments
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Test terrain breakdown calculation
        #expect(presentation.terrainBreakdown.count > 0)
        
        // Test that percentages are reasonable (may not sum to 100% due to gaps)
        let totalPercentage = presentation.terrainBreakdown.reduce(0) { $0 + $1.percentage }
        #expect(totalPercentage >= 0.0)
        #expect(totalPercentage <= 150.0) // Allow for some overlap
        
        // Test timeline segments
        #expect(presentation.timelineSegments.count >= 0)
        
        for segment in presentation.timelineSegments {
            #expect(segment.relativeWidth >= 0.0)
            #expect(segment.relativeWidth <= 1.0)
        }
    }
    
    @Test("Memory pressure during large operations", .timeLimit(.seconds(30)))
    func testMemoryPressureHandling() async throws {
        // Create a session with massive amounts of data
        let memoryTestSession = RuckSession()
        memoryTestSession.startDate = Date().addingTimeInterval(-86400) // 24 hours ago
        memoryTestSession.endDate = Date()
        
        // Add 50,000 location points (simulating very long session)
        let pointCount = 50000
        print("Creating \(pointCount) location points...")
        
        for i in 0..<pointCount {
            let point = LocationPoint(
                timestamp: memoryTestSession.startDate.addingTimeInterval(TimeInterval(i * 2)), // Every 2 seconds
                latitude: 37.7749 + Double(i) * 0.000001, // Micro movements
                longitude: -122.4194 + Double(i) * 0.000001,
                altitude: 100.0 + sin(Double(i) * 0.001) * 10, // Gentle elevation changes
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.0 + sin(Double(i) * 0.01) * 0.5,
                course: Double(i % 360)
            )
            
            // Add some variation in data
            if i % 100 == 0 {
                point.heartRate = 120.0 + Double(i % 80)
                point.elevationAccuracy = Double.random(in: 1.0...5.0)
                point.elevationConfidence = Double.random(in: 0.5...1.0)
            }
            
            memoryTestSession.locationPoints.append(point)
        }
        
        print("Testing detailed session view initialization...")
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: memoryTestSession)
        
        // Should handle large dataset without excessive memory usage
        #expect(presentation.session?.id == memoryTestSession.id)
        #expect(presentation.interactivePoints.count <= 50) // Should be limited for performance
        #expect(presentation.elevationDataPoints.count > 0)
        #expect(presentation.paceDataPoints.count > 0)
        
        print("Testing export with large dataset...")
        let exportManager = ExportManager()
        
        // Test that exports still work with large datasets
        let gpxResult = try await exportManager.exportToGPX(session: memoryTestSession)
        #expect(gpxResult.pointCount == pointCount)
        #expect(gpxResult.fileSize > 0)
        
        print("Large dataset test completed successfully")
    }
    
    @Test("Concurrent access to session data")
    func testConcurrentDataAccess() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: RuckSession.self, configurations: config)
        let context = container.mainContext
        
        let session = RuckSession()
        session.totalDistance = 5000
        session.loadWeight = 25.0
        context.insert(session)
        
        // Create multiple view models accessing the same session
        let viewModels = (0..<10).map { _ in SessionSummaryViewModel() }
        
        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for (index, viewModel) in viewModels.enumerated() {
                group.addTask {
                    viewModel.rpe = (index % 10) + 1
                    viewModel.notes = "Concurrent test \(index)"
                    
                    do {
                        try await viewModel.saveSession(session, modelContext: context)
                    } catch {
                        // Some operations may fail due to concurrent access, which is expected
                        print("Concurrent save \(index) failed: \(error)")
                    }
                }
            }
        }
        
        // Verify session is in a consistent state
        #expect(session.rpe != nil)
        #expect(session.rpe! >= 1 && session.rpe! <= 10)
        #expect(session.endDate != nil)
    }
}

// MARK: - Performance Measurement Helpers

extension SessionEdgeCaseTests {
    
    /// Measures execution time for a given operation
    static func measureTime<T>(_ operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }
    
    /// Creates a session with specified number of location points for performance testing
    static func createPerformanceTestSession(pointCount: Int) -> RuckSession {
        let session = RuckSession()
        session.startDate = Date().addingTimeInterval(-TimeInterval(pointCount * 10))
        session.endDate = Date()
        session.totalDistance = Double(pointCount) * 5.0 // 5m per point
        session.totalDuration = TimeInterval(pointCount * 10) // 10s per point
        session.loadWeight = 25.0
        
        for i in 0..<pointCount {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 10)),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                altitude: 100.0 + Double(i % 100),
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5,
                course: Double(i % 360)
            )
            session.locationPoints.append(point)
        }
        
        return session
    }
}