import Testing
import SwiftUI
import SwiftData
@testable import RuckMap

/// UI interaction and user workflow tests for Session 12 components
@Suite("Session UI Interaction Tests")
struct SessionUIInteractionTests {
    
    @Test("SessionSummaryView complete user workflow")
    func testCompleteSessionSummaryWorkflow() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: RuckSession.self, configurations: config)
        let context = container.mainContext
        
        // Create a session as if just completed
        let session = RuckSession()
        session.totalDistance = 8000 // 8km
        session.totalDuration = 3600 // 1 hour
        session.loadWeight = 30.0 // 30kg
        session.totalCalories = 750
        session.elevationGain = 300
        session.elevationLoss = 250
        session.averageGrade = 6.5
        session.averagePace = 7.5 // 7.5 min/km
        
        // Add location points for route visualization
        for i in 0..<50 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 72)), // Every 72 seconds
                latitude: 37.7749 + Double(i) * 0.0002,
                longitude: -122.4194 + Double(i) * 0.0002,
                altitude: 100.0 + sin(Double(i) * 0.2) * 30, // Elevation variation
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.0 + sin(Double(i) * 0.1) * 0.5,
                course: Double(i * 7) % 360
            )
            session.locationPoints.append(point)
        }
        
        // Add weather conditions
        let weather = WeatherConditions(
            temperature: 28.0,
            humidity: 65.0,
            windSpeed: 8.0,
            precipitation: 0.0
        )
        session.weatherConditions = weather
        
        // Add terrain segments
        let trailSegment = TerrainSegment(
            startTime: session.startDate,
            endTime: session.startDate.addingTimeInterval(2400), // 40 minutes
            terrainType: .trail,
            grade: 7.0
        )
        
        let roadSegment = TerrainSegment(
            startTime: session.startDate.addingTimeInterval(2400),
            endTime: session.startDate.addingTimeInterval(3600), // 20 minutes
            terrainType: .pavedRoad,
            grade: 3.0
        )
        
        session.terrainSegments = [trailSegment, roadSegment]
        context.insert(session)
        
        let viewModel = SessionSummaryViewModel()
        
        // Test complete user workflow
        
        // 1. User reviews session statistics
        #expect(session.totalDistance == 8000)
        #expect(session.elevationGain == 300)
        #expect(session.terrainSegments.count == 2)
        #expect(session.weatherConditions != nil)
        
        // 2. User sets RPE (simulated interaction)
        viewModel.rpe = 8 // Hard effort
        #expect(viewModel.rpe == 8)
        
        // 3. User adds notes
        viewModel.notes = "Challenging hill session with great views. Felt strong throughout despite the elevation gain."
        #expect(viewModel.notes.count > 0)
        #expect(viewModel.notes.count <= 500) // Within character limit
        
        // 4. User attempts voice recording (simulated)
        let initialRecordingState = viewModel.isRecording
        viewModel.stopVoiceRecording() // Safe operation when not recording
        #expect(viewModel.isRecording == initialRecordingState)
        
        // 5. User saves session
        #expect(viewModel.isSaving == false)
        try await viewModel.saveSession(session, modelContext: context)
        #expect(session.rpe == 8)
        #expect(session.notes == viewModel.notes)
        #expect(session.endDate != nil)
        
        // 6. Verify session is properly saved
        let fetchRequest = FetchDescriptor<RuckSession>()
        let savedSessions = try context.fetch(fetchRequest)
        #expect(savedSessions.count == 1)
        #expect(savedSessions.first?.rpe == 8)
    }
    
    @Test("SessionHistoryView filtering and sorting interactions")
    func testSessionHistoryInteractions() async throws {
        let viewModel = SessionHistoryViewModel()
        let testSessions = createComprehensiveTestSessions()
        
        viewModel.updateSessions(testSessions)
        
        // Test initial state
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedSortOption == .dateDescending)
        #expect(viewModel.hasActiveFilters == false)
        
        // 1. User searches for sessions
        viewModel.searchText = "mountain"
        let searchResults = viewModel.filteredSessions(from: testSessions)
        #expect(searchResults.count <= testSessions.count)
        
        // Clear search
        viewModel.searchText = ""
        let allResults = viewModel.filteredSessions(from: testSessions)
        #expect(allResults.count == testSessions.count)
        
        // 2. User applies time filter
        viewModel.selectedTimeRange = .month
        let monthResults = viewModel.filteredSessions(from: testSessions)
        #expect(monthResults.count <= testSessions.count)
        #expect(viewModel.hasActiveFilters == true)
        
        // 3. User applies distance filter
        viewModel.distanceRange = 3...8 // 3-8 km
        let distanceResults = viewModel.filteredSessions(from: testSessions)
        
        for session in distanceResults {
            let distanceKm = session.totalDistance / 1000
            #expect(distanceKm >= 3.0)
            #expect(distanceKm <= 8.0)
        }
        
        // 4. User applies terrain filter
        viewModel.selectedTerrainTypes = [.trail]
        let terrainResults = viewModel.filteredSessions(from: testSessions)
        
        for session in terrainResults {
            if !session.terrainSegments.isEmpty {
                let hasTrail = session.terrainSegments.contains { $0.terrainType == .trail }
                #expect(hasTrail)
            }
        }
        
        // 5. User sorts by different criteria
        let sortOptions: [SortOption] = [
            .dateAscending, .dateDescending,
            .distanceAscending, .distanceDescending,
            .durationAscending, .durationDescending,
            .caloriesAscending, .caloriesDescending
        ]
        
        for sortOption in sortOptions {
            viewModel.selectedSortOption = sortOption
            let sortedResults = viewModel.filteredSessions(from: testSessions)
            #expect(sortedResults.count > 0)
            
            // Verify sorting is applied
            if sortedResults.count > 1 {
                let first = sortedResults.first!
                let last = sortedResults.last!
                
                switch sortOption {
                case .dateAscending:
                    #expect(first.startDate <= last.startDate)
                case .dateDescending:
                    #expect(first.startDate >= last.startDate)
                case .distanceAscending:
                    #expect(first.totalDistance <= last.totalDistance)
                case .distanceDescending:
                    #expect(first.totalDistance >= last.totalDistance)
                case .durationAscending:
                    #expect(first.totalDuration <= last.totalDuration)
                case .durationDescending:
                    #expect(first.totalDuration >= last.totalDuration)
                case .caloriesAscending:
                    #expect(first.totalCalories <= last.totalCalories)
                case .caloriesDescending:
                    #expect(first.totalCalories >= last.totalCalories)
                default:
                    break
                }
            }
        }
        
        // 6. User clears all filters
        viewModel.clearAllFilters()
        #expect(viewModel.hasActiveFilters == false)
        #expect(viewModel.selectedTimeRange == .all)
        #expect(viewModel.distanceRange == 0...50)
        #expect(viewModel.selectedTerrainTypes == Set(TerrainType.allCases))
    }
    
    @Test("DetailedSessionView replay interactions")
    func testDetailedSessionReplayInteractions() async throws {
        let session = RuckSession()
        session.startDate = Date().addingTimeInterval(-7200) // 2 hours ago
        session.endDate = Date()
        session.totalDistance = 10000 // 10km
        session.totalDuration = 7200 // 2 hours
        
        // Create detailed route with 120 points (1 per minute)
        for i in 0..<120 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 60)),
                latitude: 37.7749 + Double(i) * 0.0005,
                longitude: -122.4194 + Double(i) * 0.0005,
                altitude: 100.0 + sin(Double(i) * 0.1) * 50, // Elevation changes
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.0 + sin(Double(i) * 0.05) * 0.8, // Speed variations
                course: Double(i * 3) % 360
            )
            session.locationPoints.append(point)
        }
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Test initial state
        #expect(presentation.isReplayMode == false)
        #expect(presentation.isReplaying == false)
        #expect(presentation.replayProgress == 0.0)
        #expect(presentation.isFullScreen == false)
        
        // 1. User enters replay mode
        presentation.toggleReplayMode()
        #expect(presentation.isReplayMode == true)
        #expect(presentation.mapInteractionModes == .all)
        
        // 2. User starts replay
        presentation.toggleReplay()
        #expect(presentation.isReplaying == true)
        
        // 3. User manually adjusts replay progress
        presentation.setReplayProgress(0.5) // 50% through
        #expect(presentation.replayProgress == 0.5)
        
        presentation.setReplayProgress(0.75) // 75% through
        #expect(presentation.replayProgress == 0.75)
        
        // 4. User toggles fullscreen
        presentation.toggleFullScreen()
        #expect(presentation.isFullScreen == true)
        #expect(presentation.mapInteractionModes == .all)
        
        presentation.toggleFullScreen()
        #expect(presentation.isFullScreen == false)
        #expect(presentation.mapInteractionModes == .basic)
        
        // 5. User stops replay
        presentation.stopReplay()
        #expect(presentation.isReplaying == false)
        #expect(presentation.replayProgress == 0.0)
        
        // 6. User exits replay mode
        presentation.toggleReplayMode()
        #expect(presentation.isReplayMode == false)
        #expect(presentation.mapInteractionModes == .basic)
    }
    
    @Test("Export workflow user interactions")
    func testExportWorkflowInteractions() async throws {
        let session = RuckSession()
        session.totalDistance = 12000 // 12km
        session.totalDuration = 4800 // 80 minutes
        session.loadWeight = 35.0
        session.totalCalories = 900
        session.elevationGain = 450
        session.notes = "Epic mountain ruck with amazing views!"
        session.rpe = 9
        
        // Add comprehensive location data
        for i in 0..<80 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 60)),
                latitude: 37.7749 + Double(i) * 0.0008,
                longitude: -122.4194 + Double(i) * 0.0008,
                altitude: 100.0 + Double(i) * 3.0, // Gradual elevation gain
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.2 + sin(Double(i) * 0.1) * 0.3,
                course: Double(i * 4) % 360
            )
            
            // Add additional data for comprehensive export
            if i % 10 == 0 {
                point.heartRate = 140.0 + Double(i % 40)
                point.elevationAccuracy = 2.0
                point.elevationConfidence = 0.9
                point.instantaneousGrade = Double(i % 20) - 10.0
                point.pressure = 1013.25 - Double(i) * 0.1
            }
            
            session.locationPoints.append(point)
        }
        
        let exportManager = ExportManager()
        
        // 1. User exports to GPX
        let gpxResult = try await exportManager.exportToGPX(session: session)
        #expect(gpxResult.format == .gpx)
        #expect(gpxResult.pointCount == session.locationPoints.count)
        #expect(gpxResult.fileSize > 0)
        #expect(FileManager.default.fileExists(atPath: gpxResult.url.path))
        
        // Verify GPX content
        let gpxContent = try String(contentsOf: gpxResult.url)
        #expect(gpxContent.contains("<gpx"))
        #expect(gpxContent.contains("<trk>"))
        #expect(gpxContent.contains("lat="))
        #expect(gpxContent.contains("lon="))
        
        // 2. User exports to CSV
        let csvResult = try await exportManager.exportToCSV(session: session)
        #expect(csvResult.format == .csv)
        #expect(csvResult.pointCount == session.locationPoints.count)
        
        // Verify CSV structure
        let csvContent = try String(contentsOf: csvResult.url)
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == session.locationPoints.count + 1) // Header + data
        
        let header = lines[0]
        #expect(header.contains("timestamp"))
        #expect(header.contains("latitude"))
        #expect(header.contains("longitude"))
        #expect(header.contains("altitude"))
        
        // 3. User exports to JSON
        let jsonResult = try await exportManager.exportToJSON(session: session)
        #expect(jsonResult.format == .json)
        
        // Verify JSON structure
        let jsonData = try Data(contentsOf: jsonResult.url)
        let exportedSession = try JSONDecoder().decode(ExportManager.ExportableSession.self, from: jsonData)
        #expect(exportedSession.id == session.id.uuidString)
        #expect(exportedSession.totalDistance == session.totalDistance)
        #expect(exportedSession.loadWeight == session.loadWeight)
        #expect(exportedSession.notes == session.notes)
        #expect(exportedSession.rpe == session.rpe)
        
        // 4. User saves export permanently
        let filename = "epic_mountain_ruck.gpx"
        let permanentURL = try await exportManager.saveExportPermanently(
            temporaryURL: gpxResult.url,
            filename: filename
        )
        
        #expect(FileManager.default.fileExists(atPath: permanentURL.path))
        #expect(permanentURL.lastPathComponent == filename)
        #expect(permanentURL.path.contains("Exports"))
        
        // 5. User performs batch export
        let additionalSession = RuckSession()
        additionalSession.totalDistance = 5000
        additionalSession.totalDuration = 2400
        additionalSession.locationPoints = [
            LocationPoint(timestamp: Date(), latitude: 37.7749, longitude: -122.4194, altitude: 100,
                         horizontalAccuracy: 5.0, verticalAccuracy: 3.0, speed: 1.0, course: 0)
        ]
        
        let batchResults = try await exportManager.exportBatch(
            sessions: [session, additionalSession],
            format: .gpx
        )
        
        #expect(batchResults.count == 2)
        for result in batchResults {
            #expect(result.format == .gpx)
            #expect(result.fileSize > 0)
            #expect(FileManager.default.fileExists(atPath: result.url.path))
        }
    }
    
    @Test("Multi-step filter application workflow")
    func testComplexFilteringWorkflow() async throws {
        let viewModel = SessionHistoryViewModel()
        let largeSessions = createLargeVariedDataset(count: 1000)
        
        viewModel.updateSessions(largeSessions)
        
        // Progressive filtering workflow (user gradually narrows down results)
        
        // 1. Start with all sessions
        let allSessions = viewModel.filteredSessions(from: largeSessions)
        #expect(allSessions.count == largeSessions.count)
        
        // 2. Filter by time range
        viewModel.selectedTimeRange = .year
        let yearSessions = viewModel.filteredSessions(from: largeSessions)
        #expect(yearSessions.count <= allSessions.count)
        print("After time filter: \(yearSessions.count) sessions")
        
        // 3. Add distance filter
        viewModel.distanceRange = 5...15 // 5-15km
        let distanceFiltered = viewModel.filteredSessions(from: largeSessions)
        #expect(distanceFiltered.count <= yearSessions.count)
        print("After distance filter: \(distanceFiltered.count) sessions")
        
        // 4. Add terrain filter
        viewModel.selectedTerrainTypes = [.trail, .pavedRoad]
        let terrainFiltered = viewModel.filteredSessions(from: largeSessions)
        #expect(terrainFiltered.count <= distanceFiltered.count)
        print("After terrain filter: \(terrainFiltered.count) sessions")
        
        // 5. Add performance filter
        viewModel.minCalories = 400
        viewModel.minElevationGain = 50
        let performanceFiltered = viewModel.filteredSessions(from: largeSessions)
        #expect(performanceFiltered.count <= terrainFiltered.count)
        print("After performance filter: \(performanceFiltered.count) sessions")
        
        // 6. Add weather filter
        viewModel.temperatureRange = 10...30 // Comfortable range
        viewModel.precipitationMax = 2 // Light rain or less
        let weatherFiltered = viewModel.filteredSessions(from: largeSessions)
        #expect(weatherFiltered.count <= performanceFiltered.count)
        print("After weather filter: \(weatherFiltered.count) sessions")
        
        // 7. User removes some filters (expands results)
        viewModel.selectedTerrainTypes = Set(TerrainType.allCases)
        let expandedResults = viewModel.filteredSessions(from: largeSessions)
        #expect(expandedResults.count >= weatherFiltered.count)
        print("After removing terrain filter: \(expandedResults.count) sessions")
        
        // 8. User clears all filters
        viewModel.clearAllFilters()
        let clearedResults = viewModel.filteredSessions(from: largeSessions)
        #expect(clearedResults.count == largeSessions.count)
        #expect(viewModel.hasActiveFilters == false)
        print("After clearing all filters: \(clearedResults.count) sessions")
    }
    
    @Test("RPE selection user interaction patterns")
    func testRPESelectionPatterns() async {
        let viewModel = SessionSummaryViewModel()
        
        // Test common user interaction patterns
        
        // 1. User starts with default RPE
        #expect(viewModel.rpe == 5) // Default middle value
        
        // 2. User explores different RPE values (common pattern)
        let typicalRPEProgression = [6, 7, 6, 7, 8, 7] // User adjusting up and down
        
        for rpe in typicalRPEProgression {
            viewModel.rpe = rpe
            #expect(viewModel.rpe == rpe)
            #expect(viewModel.rpe >= 1 && viewModel.rpe <= 10)
        }
        
        // 3. User tests boundary values
        viewModel.rpe = 1 // Minimum
        #expect(viewModel.rpe == 1)
        
        viewModel.rpe = 10 // Maximum
        #expect(viewModel.rpe == 10)
        
        // 4. User settles on final value
        viewModel.rpe = 7 // Common final choice for challenging sessions
        #expect(viewModel.rpe == 7)
        
        // Test RPE descriptions for all values
        for rpe in 1...10 {
            viewModel.rpe = rpe
            let description = getRPEDescription(rpe)
            #expect(!description.isEmpty)
            #expect(description.count > 3) // Should be descriptive
        }
    }
    
    @Test("Weather display interaction scenarios")
    func testWeatherDisplayInteractions() async throws {
        let weatherScenarios = [
            // Perfect conditions
            (temp: 22.0, humidity: 50.0, wind: 3.0, precip: 0.0, description: "Perfect"),
            
            // Hot conditions
            (temp: 38.0, humidity: 80.0, wind: 2.0, precip: 0.0, description: "Hot and humid"),
            
            // Cold conditions  
            (temp: -5.0, humidity: 40.0, wind: 15.0, precip: 0.0, description: "Cold and windy"),
            
            // Rainy conditions
            (temp: 15.0, humidity: 95.0, wind: 8.0, precip: 12.0, description: "Rainy"),
            
            // Extreme conditions
            (temp: 45.0, humidity: 30.0, wind: 25.0, precip: 20.0, description: "Extreme")
        ]
        
        for (temp, humidity, wind, precip, description) in weatherScenarios {
            let weather = WeatherConditions(
                temperature: temp,
                humidity: humidity,
                windSpeed: wind,
                precipitation: precip
            )
            
            // Test weather impact calculations
            let adjustmentFactor = weather.temperatureAdjustmentFactor
            #expect(adjustmentFactor > 0.0)
            #expect(!adjustmentFactor.isNaN)
            #expect(!adjustmentFactor.isInfinite)
            
            // Test harsh conditions detection
            let isHarsh = weather.isHarshConditions
            if temp > 35.0 || temp < 0.0 || wind > 20.0 || precip > 10.0 {
                #expect(isHarsh == true, "Weather should be considered harsh: \(description)")
            }
            
            // Test temperature conversions
            let fahrenheit = weather.temperatureFahrenheit
            let expectedF = temp * 9/5 + 32
            #expect(abs(fahrenheit - expectedF) < 0.1, "Temperature conversion should be accurate")
            
            // Test wind speed conversion
            let windMPH = weather.windSpeedMPH
            let expectedMPH = wind * 2.237 // m/s to mph
            #expect(abs(windMPH - expectedMPH) < 0.1, "Wind speed conversion should be accurate")
        }
    }
}

// MARK: - Test Data Helpers

extension SessionUIInteractionTests {
    
    /// Creates a comprehensive set of test sessions with varied characteristics
    static func createComprehensiveTestSessions() -> [RuckSession] {
        var sessions: [RuckSession] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Recent trail sessions
        for i in 0..<5 {
            let session = RuckSession()
            session.startDate = calendar.date(byAdding: .day, value: -i, to: now)!
            session.endDate = session.startDate.addingTimeInterval(Double(3600 + i * 600))
            session.totalDistance = Double(4000 + i * 1000) // 4-8km
            session.totalDuration = Double(3600 + i * 600)
            session.loadWeight = Double(20 + i * 3)
            session.totalCalories = Double(400 + i * 100)
            session.elevationGain = Double(100 + i * 50)
            session.rpe = 5 + i
            session.notes = "Trail session \(i + 1) with mountain views"
            
            // Add terrain
            let terrain = TerrainSegment(
                startTime: session.startDate,
                endTime: session.endDate!,
                terrainType: .trail,
                grade: Double(5 + i)
            )
            session.terrainSegments = [terrain]
            
            sessions.append(session)
        }
        
        // Road sessions
        for i in 0..<3 {
            let session = RuckSession()
            session.startDate = calendar.date(byAdding: .day, value: -(i + 10), to: now)!
            session.endDate = session.startDate.addingTimeInterval(Double(2400 + i * 300))
            session.totalDistance = Double(6000 + i * 2000) // 6-10km
            session.totalDuration = Double(2400 + i * 300)
            session.loadWeight = Double(25 + i * 5)
            session.totalCalories = Double(500 + i * 150)
            session.elevationGain = Double(50 + i * 25)
            session.rpe = 6 + i
            session.notes = "Road session \(i + 1) focusing on pace"
            
            // Add terrain
            let terrain = TerrainSegment(
                startTime: session.startDate,
                endTime: session.endDate!,
                terrainType: .pavedRoad,
                grade: Double(2 + i)
            )
            session.terrainSegments = [terrain]
            
            sessions.append(session)
        }
        
        // Add weather to some sessions
        for (index, session) in sessions.enumerated() {
            if index % 2 == 0 {
                let weather = WeatherConditions(
                    temperature: Double(15 + index * 3),
                    humidity: Double(50 + index * 5),
                    windSpeed: Double(5 + index * 2),
                    precipitation: index > 3 ? Double(index) : 0.0
                )
                session.weatherConditions = weather
            }
        }
        
        return sessions
    }
    
    /// Creates a large dataset with varied characteristics for performance testing
    static func createLargeVariedDataset(count: Int) -> [RuckSession] {
        var sessions: [RuckSession] = []
        let calendar = Calendar.current
        let now = Date()
        
        for i in 0..<count {
            let session = RuckSession()
            
            // Varied start dates over the past 2 years
            let daysBack = Int.random(in: 0...730)
            session.startDate = calendar.date(byAdding: .day, value: -daysBack, to: now)!
            
            // Varied session characteristics
            let baseDuration = Double.random(in: 1800...7200) // 30min to 2 hours
            session.totalDuration = baseDuration
            session.endDate = session.startDate.addingTimeInterval(baseDuration)
            
            session.totalDistance = Double.random(in: 2000...20000) // 2-20km
            session.loadWeight = Double.random(in: 10...50) // 10-50kg
            session.totalCalories = Double.random(in: 200...1500)
            session.elevationGain = Double.random(in: 0...800)
            session.elevationLoss = Double.random(in: 0...800)
            session.averageGrade = Double.random(in: 0...15)
            session.averagePace = Double.random(in: 6...20) // 6-20 min/km
            session.rpe = Int.random(in: 1...10)
            
            // Random notes
            let noteOptions = [
                "Great session with perfect weather",
                "Challenging mountain route with steep climbs", 
                "Recovery session after yesterday's hard effort",
                "Trail session through forest paths",
                "Urban ruck through city streets",
                "Beach walk with sand training",
                "Hill repeats for strength building",
                ""
            ]
            session.notes = noteOptions.randomElement()
            
            // Random terrain
            let terrainTypes = TerrainType.allCases
            if Bool.random() { // 50% chance of having terrain data
                let terrainType = terrainTypes.randomElement()!
                let terrain = TerrainSegment(
                    startTime: session.startDate,
                    endTime: session.endDate!,
                    terrainType: terrainType,
                    grade: Double.random(in: 0...15)
                )
                session.terrainSegments = [terrain]
            }
            
            // Random weather (30% chance)
            if Double.random() < 0.3 {
                let weather = WeatherConditions(
                    temperature: Double.random(in: -10...40),
                    humidity: Double.random(in: 30...90),
                    windSpeed: Double.random(in: 0...30),
                    precipitation: Double.random(in: 0...20)
                )
                session.weatherConditions = weather
            }
            
            sessions.append(session)
        }
        
        return sessions
    }
    
    /// Gets RPE description for a given value
    static func getRPEDescription(_ rpe: Int) -> String {
        switch rpe {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Light"  
        case 4: return "Moderate"
        case 5: return "Somewhat Hard"
        case 6: return "Hard"
        case 7: return "Very Hard"
        case 8: return "Extremely Hard"
        case 9: return "Maximum"
        case 10: return "Absolute Max"
        default: return "Unknown"
        }
    }
}