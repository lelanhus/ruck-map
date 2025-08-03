import Testing
import SwiftUI
import SwiftData
@testable import RuckMap

struct SessionHistoryViewTests {
    
    // MARK: - ViewModel Tests
    
    @Test("SessionHistoryViewModel initializes with default values")
    func testViewModelInitialization() async {
        let viewModel = SessionHistoryViewModel()
        
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedSortOption == .dateDescending)
        #expect(viewModel.showingFilterSheet == false)
        #expect(viewModel.showingDeleteAlert == false)
        #expect(viewModel.showingErrorAlert == false)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(viewModel.sessionToDelete == nil)
        
        // Filter defaults
        #expect(viewModel.selectedTimeRange == .all)
        #expect(viewModel.distanceRange == 0...50)
        #expect(viewModel.loadWeightRange == 0...100)
        #expect(viewModel.selectedTerrainTypes == Set(TerrainType.allCases))
        #expect(viewModel.temperatureRange == -20...50)
        #expect(viewModel.windSpeedMax == 50)
        #expect(viewModel.precipitationMax == 50)
        #expect(viewModel.showOnlyFavorites == false)
        #expect(viewModel.minCalories == 0)
        #expect(viewModel.minElevationGain == 0)
        #expect(viewModel.hasActiveFilters == false)
    }
    
    @Test("Filtering by search text works correctly")
    func testSearchFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessions()
        
        viewModel.updateSessions(sessions)
        
        // Test search by notes
        viewModel.searchText = "mountain"
        let mountainResults = viewModel.filteredSessions(from: sessions)
        #expect(mountainResults.count == 1)
        #expect(mountainResults.first?.notes?.contains("mountain") == true)
        
        // Test search by terrain
        viewModel.searchText = "trail"
        let trailResults = viewModel.filteredSessions(from: sessions)
        #expect(trailResults.count >= 1)
        
        // Test case insensitive search
        viewModel.searchText = "TRAIL"
        let trailResultsUpper = viewModel.filteredSessions(from: sessions)
        #expect(trailResultsUpper.count == trailResults.count)
        
        // Test no results
        viewModel.searchText = "nonexistent"
        let noResults = viewModel.filteredSessions(from: sessions)
        #expect(noResults.isEmpty)
        
        // Test empty search returns all
        viewModel.searchText = ""
        let allResults = viewModel.filteredSessions(from: sessions)
        #expect(allResults.count == sessions.count)
    }
    
    @Test("Sorting options work correctly")
    func testSortingOptions() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessions()
        
        viewModel.updateSessions(sessions)
        
        // Test date descending (default)
        viewModel.selectedSortOption = .dateDescending
        let dateDesc = viewModel.filteredSessions(from: sessions)
        #expect(dateDesc.first!.startDate >= dateDesc.last!.startDate)
        
        // Test date ascending
        viewModel.selectedSortOption = .dateAscending
        let dateAsc = viewModel.filteredSessions(from: sessions)
        #expect(dateAsc.first!.startDate <= dateAsc.last!.startDate)
        
        // Test distance descending
        viewModel.selectedSortOption = .distanceDescending
        let distDesc = viewModel.filteredSessions(from: sessions)
        #expect(distDesc.first!.totalDistance >= distDesc.last!.totalDistance)
        
        // Test duration descending
        viewModel.selectedSortOption = .durationDescending
        let durDesc = viewModel.filteredSessions(from: sessions)
        #expect(durDesc.first!.totalDuration >= durDesc.last!.totalDuration)
        
        // Test calories descending
        viewModel.selectedSortOption = .caloriesDescending
        let calDesc = viewModel.filteredSessions(from: sessions)
        #expect(calDesc.first!.totalCalories >= calDesc.last!.totalCalories)
        
        // Test elevation gain descending
        viewModel.selectedSortOption = .elevationGainDescending
        let elevDesc = viewModel.filteredSessions(from: sessions)
        #expect(elevDesc.first!.elevationGain >= elevDesc.last!.elevationGain)
    }
    
    @Test("Time range filtering works correctly")
    func testTimeRangeFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessionsWithVariousDates()
        
        viewModel.updateSessions(sessions)
        
        // Test all time (default)
        viewModel.selectedTimeRange = .all
        let allResults = viewModel.filteredSessions(from: sessions)
        #expect(allResults.count == sessions.count)
        
        // Test this week
        viewModel.selectedTimeRange = .week
        let weekResults = viewModel.filteredSessions(from: sessions)
        #expect(weekResults.count <= sessions.count)
        
        // Test this month
        viewModel.selectedTimeRange = .month
        let monthResults = viewModel.filteredSessions(from: sessions)
        #expect(monthResults.count <= sessions.count)
        #expect(monthResults.count >= weekResults.count)
        
        // Test this year
        viewModel.selectedTimeRange = .year
        let yearResults = viewModel.filteredSessions(from: sessions)
        #expect(yearResults.count >= monthResults.count)
    }
    
    @Test("Distance range filtering works correctly")
    func testDistanceRangeFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessions()
        
        viewModel.updateSessions(sessions)
        
        // Test narrow distance range
        viewModel.distanceRange = 3...7 // 3-7 km
        let filteredResults = viewModel.filteredSessions(from: sessions)
        
        for session in filteredResults {
            let distanceKm = session.totalDistance / 1000
            #expect(distanceKm >= 3.0)
            #expect(distanceKm <= 7.0)
        }
        
        // Test very narrow range
        viewModel.distanceRange = 4.5...5.5
        let narrowResults = viewModel.filteredSessions(from: sessions)
        #expect(narrowResults.count <= filteredResults.count)
    }
    
    @Test("Load weight filtering works correctly")
    func testLoadWeightFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessions()
        
        viewModel.updateSessions(sessions)
        
        // Test weight range
        viewModel.loadWeightRange = 15...25 // 15-25 kg
        let filteredResults = viewModel.filteredSessions(from: sessions)
        
        for session in filteredResults {
            #expect(session.loadWeight >= 15.0)
            #expect(session.loadWeight <= 25.0)
        }
    }
    
    @Test("Terrain type filtering works correctly")
    func testTerrainFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessions()
        
        viewModel.updateSessions(sessions)
        
        // Test single terrain type
        viewModel.selectedTerrainTypes = [.trail]
        let trailResults = viewModel.filteredSessions(from: sessions)
        
        for session in trailResults {
            let hasTrail = session.terrainSegments.contains { $0.terrainType == .trail }
            #expect(hasTrail || session.terrainSegments.isEmpty) // Empty segments are included
        }
        
        // Test multiple terrain types
        viewModel.selectedTerrainTypes = [.trail, .pavedRoad]
        let multiResults = viewModel.filteredSessions(from: sessions)
        #expect(multiResults.count >= trailResults.count)
        
        // Test no terrain types selected
        viewModel.selectedTerrainTypes = []
        let noTerrainResults = viewModel.filteredSessions(from: sessions)
        
        for session in noTerrainResults {
            #expect(session.terrainSegments.isEmpty)
        }
    }
    
    @Test("Weather filtering works correctly")
    func testWeatherFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessionsWithWeather()
        
        viewModel.updateSessions(sessions)
        
        // Test temperature range
        viewModel.temperatureRange = 0...25 // Comfortable range
        let tempResults = viewModel.filteredSessions(from: sessions)
        
        for session in tempResults {
            if let weather = session.weatherConditions {
                #expect(weather.temperature >= 0)
                #expect(weather.temperature <= 25)
            }
        }
        
        // Test wind speed
        viewModel.windSpeedMax = 10 // Low wind
        let windResults = viewModel.filteredSessions(from: sessions)
        
        for session in windResults {
            if let weather = session.weatherConditions {
                #expect(weather.windSpeed <= 10)
            }
        }
        
        // Test precipitation
        viewModel.precipitationMax = 5 // Light rain or less
        let precipResults = viewModel.filteredSessions(from: sessions)
        
        for session in precipResults {
            if let weather = session.weatherConditions {
                #expect(weather.precipitation <= 5)
            }
        }
    }
    
    @Test("Favorites filtering works correctly")
    func testFavoritesFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessions()
        
        viewModel.updateSessions(sessions)
        
        // Test show only favorites
        viewModel.showOnlyFavorites = true
        let favoriteResults = viewModel.filteredSessions(from: sessions)
        
        for session in favoriteResults {
            #expect(session.rpe != nil)
            #expect(session.rpe! >= 8) // High RPE indicates favorite
        }
        
        // Test show all
        viewModel.showOnlyFavorites = false
        let allResults = viewModel.filteredSessions(from: sessions)
        #expect(allResults.count >= favoriteResults.count)
    }
    
    @Test("Performance metrics filtering works correctly")
    func testPerformanceFiltering() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessions()
        
        viewModel.updateSessions(sessions)
        
        // Test minimum calories
        viewModel.minCalories = 400
        let calorieResults = viewModel.filteredSessions(from: sessions)
        
        for session in calorieResults {
            #expect(session.totalCalories >= 400)
        }
        
        // Test minimum elevation gain
        viewModel.minElevationGain = 100
        let elevationResults = viewModel.filteredSessions(from: sessions)
        
        for session in elevationResults {
            #expect(session.elevationGain >= 100)
        }
    }
    
    @Test("Clear all filters resets to defaults")
    func testClearAllFilters() async throws {
        let viewModel = SessionHistoryViewModel()
        
        // Set various filters
        viewModel.selectedTimeRange = .month
        viewModel.distanceRange = 5...10
        viewModel.loadWeightRange = 20...30
        viewModel.selectedTerrainTypes = [.trail]
        viewModel.temperatureRange = 10...20
        viewModel.windSpeedMax = 15
        viewModel.precipitationMax = 10
        viewModel.showOnlyFavorites = true
        viewModel.minCalories = 300
        viewModel.minElevationGain = 50
        
        #expect(viewModel.hasActiveFilters == true)
        
        // Clear all filters
        viewModel.clearAllFilters()
        
        // Verify defaults are restored
        #expect(viewModel.selectedTimeRange == .all)
        #expect(viewModel.distanceRange == 0...50)
        #expect(viewModel.loadWeightRange == 0...100)
        #expect(viewModel.selectedTerrainTypes == Set(TerrainType.allCases))
        #expect(viewModel.temperatureRange == -20...50)
        #expect(viewModel.windSpeedMax == 50)
        #expect(viewModel.precipitationMax == 50)
        #expect(viewModel.showOnlyFavorites == false)
        #expect(viewModel.minCalories == 0)
        #expect(viewModel.minElevationGain == 0)
        #expect(viewModel.hasActiveFilters == false)
    }
    
    @Test("Combined filters work together correctly")
    func testCombinedFilters() async throws {
        let viewModel = SessionHistoryViewModel()
        let sessions = createTestSessionsWithVariousAttributes()
        
        viewModel.updateSessions(sessions)
        
        // Apply multiple filters
        viewModel.selectedTimeRange = .month
        viewModel.distanceRange = 4...8
        viewModel.selectedTerrainTypes = [.trail, .pavedRoad]
        viewModel.minCalories = 300
        
        let filteredResults = viewModel.filteredSessions(from: sessions)
        
        // Verify all filters are applied
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date.distantPast
        
        for session in filteredResults {
            // Time range
            #expect(session.startDate >= monthAgo)
            
            // Distance range
            let distanceKm = session.totalDistance / 1000
            #expect(distanceKm >= 4.0)
            #expect(distanceKm <= 8.0)
            
            // Terrain types
            let hasValidTerrain = session.terrainSegments.isEmpty || 
                                 session.terrainSegments.contains { 
                                     viewModel.selectedTerrainTypes.contains($0.terrainType) 
                                 }
            #expect(hasValidTerrain)
            
            // Calories
            #expect(session.totalCalories >= 300)
        }
    }
    
    // MARK: - Statistics Tests
    
    @Test("HistoryStatistics calculates correctly")
    func testHistoryStatistics() async throws {
        let sessions = createTestSessions()
        let stats = HistoryStatistics(sessions: sessions)
        
        #expect(stats.totalSessions == sessions.count)
        #expect(stats.totalDistance == sessions.reduce(0) { $0 + $1.totalDistance })
        #expect(stats.totalDuration == sessions.reduce(0) { $0 + $1.totalDuration })
        #expect(stats.totalCalories == sessions.reduce(0) { $0 + $1.totalCalories })
        
        // Test averages
        if stats.totalSessions > 0 {
            #expect(stats.averageDistance == stats.totalDistance / Double(stats.totalSessions))
            #expect(stats.averageDuration == stats.totalDuration / Double(stats.totalSessions))
            #expect(stats.averageCalories == stats.totalCalories / Double(stats.totalSessions))
        }
    }
    
    @Test("StatTrend enum properties work correctly")
    func testStatTrend() async throws {
        // Test trend icons
        #expect(StatTrend.up.icon == "arrow.up")
        #expect(StatTrend.down.icon == "arrow.down")
        #expect(StatTrend.stable.icon == "minus")
        
        // Test trend colors
        #expect(StatTrend.up.color == .green)
        #expect(StatTrend.down.color == .red)
        #expect(StatTrend.stable.color == .gray)
    }
    
    // MARK: - Sort and Time Range Enums Tests
    
    @Test("SortOption enum has correct system images")
    func testSortOptionSystemImages() async throws {
        #expect(SortOption.dateDescending.systemImage == "calendar")
        #expect(SortOption.dateAscending.systemImage == "calendar")
        #expect(SortOption.distanceDescending.systemImage == "map")
        #expect(SortOption.distanceAscending.systemImage == "map")
        #expect(SortOption.durationDescending.systemImage == "clock")
        #expect(SortOption.durationAscending.systemImage == "clock")
        #expect(SortOption.caloriesDescending.systemImage == "flame")
        #expect(SortOption.caloriesAscending.systemImage == "flame")
        #expect(SortOption.averagePaceDescending.systemImage == "speedometer")
        #expect(SortOption.averagePaceAscending.systemImage == "speedometer")
        #expect(SortOption.elevationGainDescending.systemImage == "mountain.2")
        #expect(SortOption.elevationGainAscending.systemImage == "mountain.2")
    }
    
    @Test("TimeRange enum has correct system images")
    func testTimeRangeSystemImages() async throws {
        #expect(TimeRange.all.systemImage == "infinity")
        #expect(TimeRange.week.systemImage == "calendar.day.timeline.left")
        #expect(TimeRange.month.systemImage == "calendar")
        #expect(TimeRange.threeMonths.systemImage == "calendar.badge.clock")
        #expect(TimeRange.sixMonths.systemImage == "calendar.badge.clock")
        #expect(TimeRange.year.systemImage == "calendar.circle")
    }
    
    // MARK: - Performance Tests
    
    @Test("Large dataset filtering performance")
    func testLargeDatasetPerformance() async throws {
        let viewModel = SessionHistoryViewModel()
        let largeSessions = createLargeTestDataset(count: 1000)
        
        viewModel.updateSessions(largeSessions)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Apply complex filtering
        viewModel.searchText = "trail"
        viewModel.selectedTimeRange = .year
        viewModel.distanceRange = 3...10
        viewModel.selectedTerrainTypes = [.trail, .pavedRoad, .gravel]
        
        let results = viewModel.filteredSessions(from: largeSessions)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let processingTime = endTime - startTime
        
        // Filtering should complete in reasonable time (< 1 second)
        #expect(processingTime < 1.0)
        #expect(results.count <= largeSessions.count)
    }
    
    // MARK: - Accessibility Tests
    
    @Test("Accessibility labels are properly formatted")
    func testAccessibilityLabels() async throws {
        let session = createTestSessions().first!
        
        // Test that session can be described for accessibility
        let distance = FormatUtilities.formatDistance(session.totalDistance, units: "imperial")
        let duration = FormatUtilities.formatDuration(session.totalDuration)
        let date = FormatUtilities.formatSessionDate(session.startDate)
        let weight = FormatUtilities.formatWeight(session.loadWeight, units: "imperial")
        
        #expect(!distance.isEmpty)
        #expect(!duration.isEmpty)
        #expect(!date.isEmpty)
        #expect(!weight.isEmpty)
        
        // Test accessibility label construction
        let accessibilityLabel = "Ruck session: \(distance), \(duration), \(weight) load, on \(date)"
        #expect(accessibilityLabel.contains("Ruck session"))
        #expect(accessibilityLabel.contains(distance))
        #expect(accessibilityLabel.contains(duration))
    }
}

// MARK: - Test Data Creation Helpers

extension SessionHistoryViewTests {
    
    /// Creates a set of test sessions with various attributes
    static func createTestSessions() -> [RuckSession] {
        var sessions: [RuckSession] = []
        
        // Session 1: Recent trail ruck
        let session1 = RuckSession()
        session1.startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        session1.endDate = Date()
        session1.totalDistance = 5000 // 5km
        session1.totalDuration = 3600 // 1 hour
        session1.loadWeight = 20.0
        session1.totalCalories = 450
        session1.elevationGain = 150
        session1.elevationLoss = 100
        session1.averageGrade = 5.5
        session1.averagePace = 12.0
        session1.rpe = 6
        session1.notes = "Great trail ruck through the forest"
        
        let terrain1 = TerrainSegment(
            startTime: session1.startDate,
            endTime: session1.endDate!,
            terrainType: .trail,
            grade: 5.5
        )
        session1.terrainSegments = [terrain1]
        sessions.append(session1)
        
        // Session 2: Road ruck with high intensity
        let session2 = RuckSession()
        session2.startDate = Date().addingTimeInterval(-86400) // 1 day ago
        session2.endDate = Date().addingTimeInterval(-82800) // 1 hour duration
        session2.totalDistance = 8000 // 8km
        session2.totalDuration = 3600
        session2.loadWeight = 25.0
        session2.totalCalories = 650
        session2.elevationGain = 50
        session2.elevationLoss = 50
        session2.averageGrade = 1.0
        session2.averagePace = 7.5
        session2.rpe = 8 // High intensity (favorite)
        session2.notes = "Fast paced road ruck"
        
        let terrain2 = TerrainSegment(
            startTime: session2.startDate,
            endTime: session2.endDate!,
            terrainType: .pavedRoad,
            grade: 1.0
        )
        session2.terrainSegments = [terrain2]
        sessions.append(session2)
        
        // Session 3: Mountain ruck with challenging conditions
        let session3 = RuckSession()
        session3.startDate = Date().addingTimeInterval(-172800) // 2 days ago
        session3.endDate = Date().addingTimeInterval(-165600) // 2 hour duration
        session3.totalDistance = 6000 // 6km
        session3.totalDuration = 7200 // 2 hours
        session3.loadWeight = 30.0
        session3.totalCalories = 800
        session3.elevationGain = 300
        session3.elevationLoss = 300
        session3.averageGrade = 8.0
        session3.averagePace = 20.0
        session3.rpe = 9 // Very high intensity (favorite)
        session3.notes = "Challenging mountain ruck with steep grades"
        
        let terrain3 = TerrainSegment(
            startTime: session3.startDate,
            endTime: session3.endDate!,
            terrainType: .trail,
            grade: 8.0
        )
        session3.terrainSegments = [terrain3]
        sessions.append(session3)
        
        // Session 4: Light recovery ruck
        let session4 = RuckSession()
        session4.startDate = Date().addingTimeInterval(-259200) // 3 days ago
        session4.endDate = Date().addingTimeInterval(-257400) // 30 min duration
        session4.totalDistance = 3000 // 3km
        session4.totalDuration = 1800 // 30 minutes
        session4.loadWeight = 15.0
        session4.totalCalories = 200
        session4.elevationGain = 20
        session4.elevationLoss = 20
        session4.averageGrade = 0.5
        session4.averagePace = 10.0
        session4.rpe = 3 // Low intensity
        session4.notes = "Easy recovery ruck"
        
        let terrain4 = TerrainSegment(
            startTime: session4.startDate,
            endTime: session4.endDate!,
            terrainType: .pavedRoad,
            grade: 0.5
        )
        session4.terrainSegments = [terrain4]
        sessions.append(session4)
        
        return sessions
    }
    
    /// Creates test sessions with various dates
    static func createTestSessionsWithVariousDates() -> [RuckSession] {
        var sessions: [RuckSession] = []
        let calendar = Calendar.current
        let now = Date()
        
        // Session from this week
        let weekSession = RuckSession()
        weekSession.startDate = calendar.date(byAdding: .day, value: -3, to: now)!
        weekSession.endDate = weekSession.startDate.addingTimeInterval(3600)
        weekSession.totalDistance = 5000
        weekSession.totalDuration = 3600
        weekSession.loadWeight = 20.0
        weekSession.totalCalories = 400
        sessions.append(weekSession)
        
        // Session from this month
        let monthSession = RuckSession()
        monthSession.startDate = calendar.date(byAdding: .day, value: -15, to: now)!
        monthSession.endDate = monthSession.startDate.addingTimeInterval(3600)
        monthSession.totalDistance = 6000
        monthSession.totalDuration = 3600
        monthSession.loadWeight = 25.0
        monthSession.totalCalories = 500
        sessions.append(monthSession)
        
        // Session from this year
        let yearSession = RuckSession()
        yearSession.startDate = calendar.date(byAdding: .month, value: -3, to: now)!
        yearSession.endDate = yearSession.startDate.addingTimeInterval(3600)
        yearSession.totalDistance = 7000
        yearSession.totalDuration = 3600
        yearSession.loadWeight = 30.0
        yearSession.totalCalories = 600
        sessions.append(yearSession)
        
        // Old session from last year
        let oldSession = RuckSession()
        oldSession.startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        oldSession.endDate = oldSession.startDate.addingTimeInterval(3600)
        oldSession.totalDistance = 4000
        oldSession.totalDuration = 3600
        oldSession.loadWeight = 18.0
        oldSession.totalCalories = 350
        sessions.append(oldSession)
        
        return sessions
    }
    
    /// Creates test sessions with weather conditions
    static func createTestSessionsWithWeather() -> [RuckSession] {
        var sessions: [RuckSession] = []
        
        // Cold weather session
        let coldSession = RuckSession()
        coldSession.startDate = Date().addingTimeInterval(-3600)
        coldSession.endDate = Date()
        coldSession.totalDistance = 5000
        coldSession.totalDuration = 3600
        coldSession.loadWeight = 20.0
        coldSession.totalCalories = 450
        
        let coldWeather = WeatherConditions(
            temperature: -5.0,
            humidity: 60.0,
            windSpeed: 5.0,
            precipitation: 0.0
        )
        coldSession.weatherConditions = coldWeather
        sessions.append(coldSession)
        
        // Hot weather session
        let hotSession = RuckSession()
        hotSession.startDate = Date().addingTimeInterval(-7200)
        hotSession.endDate = Date().addingTimeInterval(-3600)
        hotSession.totalDistance = 6000
        hotSession.totalDuration = 3600
        hotSession.loadWeight = 25.0
        hotSession.totalCalories = 600
        
        let hotWeather = WeatherConditions(
            temperature: 35.0,
            humidity: 80.0,
            windSpeed: 2.0,
            precipitation: 0.0
        )
        hotSession.weatherConditions = hotWeather
        sessions.append(hotSession)
        
        // Rainy session
        let rainySession = RuckSession()
        rainySession.startDate = Date().addingTimeInterval(-10800)
        rainySession.endDate = Date().addingTimeInterval(-7200)
        rainySession.totalDistance = 4000
        rainySession.totalDuration = 3600
        rainySession.loadWeight = 22.0
        rainySession.totalCalories = 400
        
        let rainyWeather = WeatherConditions(
            temperature: 15.0,
            humidity: 90.0,
            windSpeed: 15.0,
            precipitation: 10.0
        )
        rainySession.weatherConditions = rainyWeather
        sessions.append(rainySession)
        
        // Perfect conditions session
        let perfectSession = RuckSession()
        perfectSession.startDate = Date().addingTimeInterval(-14400)
        perfectSession.endDate = Date().addingTimeInterval(-10800)
        perfectSession.totalDistance = 7000
        perfectSession.totalDuration = 3600
        perfectSession.loadWeight = 28.0
        perfectSession.totalCalories = 550
        
        let perfectWeather = WeatherConditions(
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 3.0,
            precipitation: 0.0
        )
        perfectSession.weatherConditions = perfectWeather
        sessions.append(perfectSession)
        
        return sessions
    }
    
    /// Creates test sessions with various attributes for combined filtering
    static func createTestSessionsWithVariousAttributes() -> [RuckSession] {
        var sessions = createTestSessions()
        sessions.append(contentsOf: createTestSessionsWithVariousDates())
        sessions.append(contentsOf: createTestSessionsWithWeather())
        return sessions
    }
    
    /// Creates a large dataset for performance testing
    static func createLargeTestDataset(count: Int) -> [RuckSession] {
        var sessions: [RuckSession] = []
        let terrainTypes = TerrainType.allCases
        
        for i in 0..<count {
            let session = RuckSession()
            session.startDate = Date().addingTimeInterval(-TimeInterval(i * 3600)) // Each session 1 hour apart
            session.endDate = session.startDate.addingTimeInterval(3600)
            session.totalDistance = Double.random(in: 2000...15000) // 2-15km
            session.totalDuration = 3600
            session.loadWeight = Double.random(in: 10...40) // 10-40kg
            session.totalCalories = Double.random(in: 200...1000)
            session.elevationGain = Double.random(in: 0...500)
            session.elevationLoss = Double.random(in: 0...500)
            session.averageGrade = Double.random(in: 0...15)
            session.averagePace = Double.random(in: 6...20)
            session.rpe = Int.random(in: 1...10)
            session.notes = i % 3 == 0 ? "Trail ruck session \(i)" : "Road ruck session \(i)"
            
            // Add terrain segment
            let terrain = TerrainSegment(
                startTime: session.startDate,
                endTime: session.endDate!,
                terrainType: terrainTypes.randomElement()!,
                grade: session.averageGrade
            )
            session.terrainSegments = [terrain]
            
            // Add weather for some sessions
            if i % 2 == 0 {
                let weather = WeatherConditions(
                    temperature: Double.random(in: -10...40),
                    humidity: Double.random(in: 30...90),
                    windSpeed: Double.random(in: 0...20),
                    precipitation: Double.random(in: 0...20)
                )
                session.weatherConditions = weather
            }
            
            sessions.append(session)
        }
        
        return sessions
    }
}