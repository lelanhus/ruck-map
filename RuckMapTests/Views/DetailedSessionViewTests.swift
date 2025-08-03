import Testing
import SwiftUI
import SwiftData
@testable import RuckMap

/// Tests for the detailed session view with route replay functionality
@Suite("Detailed Session View Tests")
struct DetailedSessionViewTests {
    
    @Test("Session detail view initializes correctly") 
    func testSessionDetailViewInitialization() {
        // Given
        let session = RuckSession()
        session.startDate = Date()
        session.totalDistance = 5000 // 5km
        session.loadWeight = 20 // 20kg
        
        // When
        let view = DetailedSessionView(session: session)
        
        // Then
        #expect(view.session.id == session.id)
    }
    
    @Test("Session detail presentation initializes with correct data")
    func testSessionDetailPresentationInitialization() async {
        // Given
        let session = RuckSession()
        session.startDate = Date()
        session.totalDistance = 3000 // 3km
        session.totalDuration = 1800 // 30 minutes
        session.loadWeight = 15 // 15kg
        session.totalCalories = 400
        
        // Add some location points
        let startLocation = LocationPoint(
            timestamp: session.startDate,
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.5,
            course: 45.0
        )
        
        let endLocation = LocationPoint(
            timestamp: session.startDate.addingTimeInterval(1800),
            latitude: 37.7849,
            longitude: -122.4094,
            altitude: 120.0,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.2,
            course: 90.0
        )
        
        session.locationPoints = [startLocation, endLocation]
        
        // When
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Then
        #expect(presentation.session?.id == session.id)
        #expect(presentation.formattedDistance.contains("3.00"))
        #expect(presentation.formattedCalories == "400")
        #expect(presentation.formattedLoadWeight.contains("15.0"))
    }
    
    @Test("Replay controls work correctly")
    func testReplayControls() async {
        // Given
        let session = RuckSession()
        session.startDate = Date()
        session.endDate = Date().addingTimeInterval(3600) // 1 hour session
        
        // Add location points for replay
        for i in 0..<100 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 36)), // Every 36 seconds
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                altitude: 100.0 + Double(i) * 0.5,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5,
                course: 45.0
            )
            session.locationPoints.append(point)
        }
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // When - Start replay mode
        presentation.toggleReplayMode()
        
        // Then
        #expect(presentation.isReplayMode == true)
        #expect(presentation.replayProgress == 0.0)
        
        // When - Start replay
        presentation.toggleReplay()
        
        // Then
        #expect(presentation.isReplaying == true)
        
        // When - Stop replay
        presentation.stopReplay()
        
        // Then
        #expect(presentation.isReplaying == false)
        #expect(presentation.replayProgress == 0.0)
    }
    
    @Test("Chart data generation works correctly")
    func testChartDataGeneration() async {
        // Given
        let session = RuckSession()
        session.startDate = Date()
        session.endDate = Date().addingTimeInterval(1800) // 30 minutes
        
        // Add location points with varying elevation and pace
        for i in 0..<30 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 60)), // Every minute
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                altitude: 100.0 + sin(Double(i) * 0.2) * 50, // Varying elevation
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.0 + sin(Double(i) * 0.1) * 0.5, // Varying speed
                course: 45.0
            )
            session.locationPoints.append(point)
        }
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Then - Check that chart data was generated
        #expect(presentation.elevationDataPoints.count > 0)
        #expect(presentation.paceDataPoints.count > 0)
        #expect(presentation.chartStartTime == session.startDate)
        #expect(presentation.chartEndTime == session.endDate)
    }
    
    @Test("Terrain breakdown calculation works correctly")
    func testTerrainBreakdownCalculation() async {
        // Given
        let session = RuckSession()
        session.startDate = Date()
        session.endDate = Date().addingTimeInterval(3600) // 1 hour
        
        // Add terrain segments
        let trailSegment = TerrainSegment(
            startTime: session.startDate,
            endTime: session.startDate.addingTimeInterval(1800), // 30 minutes
            terrainType: .trail,
            grade: 5.0
        )
        
        let roadSegment = TerrainSegment(
            startTime: session.startDate.addingTimeInterval(1800),
            endTime: session.endDate!, // 30 minutes
            terrainType: .pavedRoad,
            grade: 2.0
        )
        
        session.terrainSegments = [trailSegment, roadSegment]
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Then - Check terrain breakdown
        #expect(presentation.terrainBreakdown.count == 2)
        
        let trailData = presentation.terrainBreakdown.first { $0.terrain == .trail }
        let roadData = presentation.terrainBreakdown.first { $0.terrain == .pavedRoad }
        
        #expect(trailData?.percentage == 50.0) // 30 minutes out of 60
        #expect(roadData?.percentage == 50.0) // 30 minutes out of 60
    }
    
    @Test("Map interaction modes work correctly")
    func testMapInteractionModes() async {
        // Given
        let session = RuckSession()
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // When - Toggle fullscreen
        presentation.toggleFullScreen()
        
        // Then
        #expect(presentation.isFullScreen == true)
        #expect(presentation.mapInteractionModes == .all)
        
        // When - Exit fullscreen
        presentation.toggleFullScreen()
        
        // Then
        #expect(presentation.isFullScreen == false)
        #expect(presentation.mapInteractionModes == .basic)
    }
    
    @Test("Distance and pace formatting works correctly")
    func testFormattingMethods() async {
        // Given
        let session = RuckSession()
        session.totalDistance = 5000 // 5km
        session.totalDuration = 1800 // 30 minutes
        session.averagePace = 6.0 // 6 minutes per km
        session.totalCalories = 500
        session.elevationGain = 200
        session.loadWeight = 25
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Then - Check formatted values
        #expect(presentation.formattedDistance.contains("5.00"))
        #expect(presentation.formattedDuration.contains("30:00"))
        #expect(presentation.formattedAveragePace.contains("6:00"))
        #expect(presentation.formattedCalories == "500")
        #expect(presentation.formattedElevationGain.contains("200"))
        #expect(presentation.formattedLoadWeight.contains("25.0"))
    }
    
    @Test("Interactive points generation respects performance limits")
    func testInteractivePointsPerformance() async {
        // Given - Large session with many location points
        let session = RuckSession()
        session.startDate = Date()
        
        // Add 1000 location points (should be reduced to max 50 interactive points)
        for i in 0..<1000 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 10)),
                latitude: 37.7749 + Double(i) * 0.00001,
                longitude: -122.4194 + Double(i) * 0.00001,
                altitude: 100.0,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5,
                course: 45.0
            )
            session.locationPoints.append(point)
        }
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Then - Should limit interactive points for performance
        #expect(presentation.interactivePoints.count <= 50)
        #expect(presentation.interactivePoints.count > 0)
    }
    
    @Test("Timeline segments are generated correctly")
    func testTimelineSegments() async {
        // Given
        let session = RuckSession()
        session.startDate = Date()
        session.endDate = Date().addingTimeInterval(1800) // 30 minutes
        
        // Add two equal terrain segments
        let segment1 = TerrainSegment(
            startTime: session.startDate,
            endTime: session.startDate.addingTimeInterval(900), // 15 minutes
            terrainType: .trail,
            grade: 5.0
        )
        
        let segment2 = TerrainSegment(
            startTime: session.startDate.addingTimeInterval(900),
            endTime: session.endDate!, // 15 minutes
            terrainType: .pavedRoad,
            grade: 2.0
        )
        
        session.terrainSegments = [segment1, segment2]
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Then - Should have timeline segments with correct relative widths
        #expect(presentation.timelineSegments.count == 2)
        
        for segment in presentation.timelineSegments {
            #expect(segment.relativeWidth == 0.5) // Each segment is 50% of total duration
        }
    }
}

// MARK: - Mock Data Extensions

extension RuckSession {
    static func mockSession(
        distance: Double = 5000,
        duration: TimeInterval = 1800,
        loadWeight: Double = 20,
        calories: Double = 400
    ) -> RuckSession {
        let session = RuckSession()
        session.totalDistance = distance
        session.totalDuration = duration
        session.loadWeight = loadWeight
        session.totalCalories = calories
        session.startDate = Date().addingTimeInterval(-duration)
        session.endDate = Date()
        return session
    }
}

extension LocationPoint {
    static func mockPoint(
        at coordinate: (lat: Double, lon: Double),
        timestamp: Date = Date(),
        altitude: Double = 100.0
    ) -> LocationPoint {
        return LocationPoint(
            timestamp: timestamp,
            latitude: coordinate.lat,
            longitude: coordinate.lon,
            altitude: altitude,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.5,
            course: 45.0
        )
    }
}