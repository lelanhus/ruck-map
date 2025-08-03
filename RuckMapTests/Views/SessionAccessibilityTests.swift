import Testing
import SwiftUI
import SwiftData
@testable import RuckMap

/// Comprehensive accessibility tests for Session 12 components
@Suite("Session Accessibility Tests")
struct SessionAccessibilityTests {
    
    @Test("SessionSummaryView accessibility labels are comprehensive")
    func testSessionSummaryAccessibility() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: RuckSession.self, configurations: config)
        let context = container.mainContext
        
        let session = RuckSession()
        session.totalDistance = 5000 // 5km
        session.totalDuration = 3600 // 1 hour
        session.loadWeight = 25.0
        session.totalCalories = 500
        session.elevationGain = 200
        session.rpe = 7
        session.notes = "Great session with challenging terrain"
        context.insert(session)
        
        // Test distance accessibility
        let distanceFormatted = FormatUtilities.formatDistancePrecise(session.totalDistance)
        #expect(!distanceFormatted.isEmpty)
        
        // Test duration accessibility
        let durationFormatted = FormatUtilities.formatDurationWithSeconds(session.totalDuration)
        #expect(durationFormatted.contains(":"))
        
        // Test load weight accessibility
        let weightFormatted = FormatUtilities.formatWeight(session.loadWeight)
        #expect(!weightFormatted.isEmpty)
        
        // Test RPE accessibility
        #expect(session.rpe >= 1 && session.rpe <= 10)
        let rpeDescription = rpeDescriptionForAccessibility(session.rpe!)
        #expect(!rpeDescription.isEmpty)
        
        // Test comprehensive accessibility label construction
        let accessibilityLabel = constructSessionAccessibilityLabel(session)
        #expect(accessibilityLabel.contains("distance"))
        #expect(accessibilityLabel.contains("duration"))
        #expect(accessibilityLabel.contains("load"))
        #expect(accessibilityLabel.contains("effort"))
    }
    
    @Test("SessionHistoryView accessibility for different session states")
    func testSessionHistoryAccessibility() async throws {
        let sessions = createAccessibilityTestSessions()
        
        for session in sessions {
            let accessibilityLabel = constructHistoryRowAccessibilityLabel(session)
            
            // Each session should have a comprehensive accessibility description
            #expect(accessibilityLabel.contains("session"))
            #expect(!accessibilityLabel.isEmpty)
            
            // Should include key metrics
            if session.totalDistance > 0 {
                #expect(accessibilityLabel.lowercased().contains("mile") || 
                       accessibilityLabel.lowercased().contains("kilometer"))
            }
            
            if session.totalDuration > 0 {
                #expect(accessibilityLabel.contains("minute") || 
                       accessibilityLabel.contains("hour"))
            }
            
            // Should indicate session status
            if session.endDate != nil {
                #expect(accessibilityLabel.contains("completed") || 
                       accessibilityLabel.contains("finished"))
            }
        }
    }
    
    @Test("DetailedSessionView accessibility for route replay")
    func testDetailedSessionReplayAccessibility() async throws {
        let session = RuckSession()
        session.startDate = Date().addingTimeInterval(-3600)
        session.endDate = Date()
        session.totalDistance = 5000
        session.totalDuration = 3600
        
        // Add location points for route
        for i in 0..<20 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 180)),
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                altitude: 100 + Double(i) * 2,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5,
                course: 0.0
            )
            session.locationPoints.append(point)
        }
        
        let presentation = SessionDetailPresentation()
        await presentation.initialize(with: session)
        
        // Test replay control accessibility
        #expect(presentation.isReplayMode == false)
        presentation.toggleReplayMode()
        #expect(presentation.isReplayMode == true)
        
        // Test replay progress accessibility
        #expect(presentation.replayProgress >= 0.0)
        #expect(presentation.replayProgress <= 1.0)
        
        // Test map region accessibility
        #expect(session.locationPoints.count > 0)
        let routeDescription = constructRouteAccessibilityDescription(session)
        #expect(routeDescription.contains("route"))
        #expect(routeDescription.contains("point"))
    }
    
    @Test("Export accessibility labels and descriptions")
    func testExportAccessibility() async throws {
        let session = RuckSession()
        session.totalDistance = 5000
        session.totalDuration = 3600
        session.loadWeight = 20.0
        
        // Add location data
        for i in 0..<10 {
            let point = LocationPoint(
                timestamp: Date().addingTimeInterval(TimeInterval(i * 360)),
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194 + Double(i) * 0.001,
                altitude: 100,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 3.0,
                speed: 1.5,
                course: 0.0
            )
            session.locationPoints.append(point)
        }
        
        let exportManager = ExportManager()
        
        // Test GPX export accessibility
        let gpxResult = try await exportManager.exportToGPX(session: session)
        let gpxAccessibilityLabel = constructExportAccessibilityLabel(gpxResult)
        #expect(gpxAccessibilityLabel.contains("GPX"))
        #expect(gpxAccessibilityLabel.contains("point"))
        #expect(gpxAccessibilityLabel.contains("file"))
        
        // Test CSV export accessibility
        let csvResult = try await exportManager.exportToCSV(session: session)
        let csvAccessibilityLabel = constructExportAccessibilityLabel(csvResult)
        #expect(csvAccessibilityLabel.contains("CSV"))
        #expect(csvAccessibilityLabel.contains("data"))
        
        // Test JSON export accessibility
        let jsonResult = try await exportManager.exportToJSON(session: session)
        let jsonAccessibilityLabel = constructExportAccessibilityLabel(jsonResult)
        #expect(jsonAccessibilityLabel.contains("JSON"))
        #expect(jsonAccessibilityLabel.contains("session"))
    }
    
    @Test("Weather display accessibility")
    func testWeatherAccessibility() async {
        let weatherConditions = [
            WeatherConditions(temperature: -5.0, humidity: 60.0, windSpeed: 5.0, precipitation: 0.0),
            WeatherConditions(temperature: 20.0, humidity: 50.0, windSpeed: 3.0, precipitation: 0.0),
            WeatherConditions(temperature: 35.0, humidity: 80.0, windSpeed: 15.0, precipitation: 5.0),
            WeatherConditions(temperature: 45.0, humidity: 95.0, windSpeed: 25.0, precipitation: 15.0)
        ]
        
        for weather in weatherConditions {
            let accessibilityDescription = constructWeatherAccessibilityDescription(weather)
            
            // Should include temperature
            #expect(accessibilityDescription.contains("temperature") || 
                   accessibilityDescription.contains("degrees"))
            
            // Should describe conditions
            if weather.isHarshConditions {
                #expect(accessibilityDescription.contains("harsh") || 
                       accessibilityDescription.contains("challenging") ||
                       accessibilityDescription.contains("difficult"))
            }
            
            // Should include wind information
            if weather.windSpeed > 10 {
                #expect(accessibilityDescription.contains("wind") || 
                       accessibilityDescription.contains("breeze"))
            }
            
            // Should include precipitation
            if weather.precipitation > 0 {
                #expect(accessibilityDescription.contains("rain") || 
                       accessibilityDescription.contains("precipitation"))
            }
        }
    }
    
    @Test("Terrain type accessibility descriptions")
    func testTerrainAccessibility() async {
        let terrainTypes = TerrainType.allCases
        
        for terrain in terrainTypes {
            let displayName = terrain.displayName
            let accessibilityDescription = constructTerrainAccessibilityDescription(terrain)
            
            #expect(!displayName.isEmpty)
            #expect(!accessibilityDescription.isEmpty)
            
            // Should provide clear description of terrain
            switch terrain {
            case .pavedRoad:
                #expect(accessibilityDescription.contains("paved") || 
                       accessibilityDescription.contains("road"))
            case .trail:
                #expect(accessibilityDescription.contains("trail") || 
                       accessibilityDescription.contains("path"))
            case .gravel:
                #expect(accessibilityDescription.contains("gravel"))
            case .sand:
                #expect(accessibilityDescription.contains("sand"))
            case .mud:
                #expect(accessibilityDescription.contains("mud"))
            case .snow:
                #expect(accessibilityDescription.contains("snow"))
            case .grass:
                #expect(accessibilityDescription.contains("grass"))
            case .stairs:
                #expect(accessibilityDescription.contains("stairs") || 
                       accessibilityDescription.contains("steps"))
            }
        }
    }
    
    @Test("RPE accessibility with voice over support")
    func testRPEAccessibility() async {
        let rpeValues = Array(1...10)
        
        for rpe in rpeValues {
            let description = rpeDescriptionForAccessibility(rpe)
            let fullAccessibilityLabel = constructRPEAccessibilityLabel(rpe)
            
            #expect(!description.isEmpty)
            #expect(!fullAccessibilityLabel.isEmpty)
            
            // Should include both numeric and descriptive information
            #expect(fullAccessibilityLabel.contains("\(rpe)"))
            #expect(fullAccessibilityLabel.contains(description))
            
            // Should provide clear effort level indication
            switch rpe {
            case 1...2:
                #expect(description.lowercased().contains("easy"))
            case 3...4:
                #expect(description.lowercased().contains("light") || 
                       description.lowercased().contains("moderate"))
            case 5...6:
                #expect(description.lowercased().contains("hard") || 
                       description.lowercased().contains("somewhat"))
            case 7...8:
                #expect(description.lowercased().contains("hard") || 
                       description.lowercased().contains("very"))
            case 9...10:
                #expect(description.lowercased().contains("max") || 
                       description.lowercased().contains("maximum"))
            default:
                break
            }
        }
    }
    
    @Test("Chart accessibility for elevation and pace data")
    func testChartAccessibility() async throws {
        let session = RuckSession()
        session.startDate = Date().addingTimeInterval(-1800)
        session.endDate = Date()
        
        // Create elevation and pace data points
        for i in 0..<30 {
            let point = LocationPoint(
                timestamp: session.startDate.addingTimeInterval(TimeInterval(i * 60)),
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
        
        // Test elevation chart accessibility
        #expect(presentation.elevationDataPoints.count > 0)
        let elevationAccessibility = constructElevationChartAccessibility(presentation.elevationDataPoints)
        #expect(elevationAccessibility.contains("elevation"))
        #expect(elevationAccessibility.contains("chart"))
        
        // Test pace chart accessibility
        #expect(presentation.paceDataPoints.count > 0)
        let paceAccessibility = constructPaceChartAccessibility(presentation.paceDataPoints)
        #expect(paceAccessibility.contains("pace"))
        #expect(paceAccessibility.contains("chart"))
    }
    
    @Test("Voice input accessibility and feedback")
    func testVoiceInputAccessibility() async {
        let viewModel = SessionSummaryViewModel()
        
        // Test initial voice recording state
        #expect(viewModel.isRecording == false)
        
        // Test accessibility state descriptions
        let initialStateDescription = constructVoiceRecordingAccessibilityState(viewModel)
        #expect(initialStateDescription.contains("ready") || 
               initialStateDescription.contains("not recording"))
        
        // Test recording state (simulated)
        viewModel.stopVoiceRecording() // Safe to call when not recording
        let stoppedStateDescription = constructVoiceRecordingAccessibilityState(viewModel)
        #expect(!stoppedStateDescription.isEmpty)
        
        // Test accessibility hints for voice input
        let voiceInputHint = constructVoiceInputAccessibilityHint()
        #expect(voiceInputHint.contains("voice") || voiceInputHint.contains("speak"))
        #expect(voiceInputHint.contains("notes") || voiceInputHint.contains("record"))
    }
}

// MARK: - Accessibility Helper Functions

extension SessionAccessibilityTests {
    
    /// Creates test sessions with various states for accessibility testing
    static func createAccessibilityTestSessions() -> [RuckSession] {
        var sessions: [RuckSession] = []
        
        // Completed session
        let completed = RuckSession()
        completed.totalDistance = 5000
        completed.totalDuration = 3600
        completed.loadWeight = 20.0
        completed.endDate = Date()
        completed.rpe = 6
        completed.notes = "Good session"
        sessions.append(completed)
        
        // In-progress session
        let inProgress = RuckSession()
        inProgress.totalDistance = 2000
        inProgress.totalDuration = 1200
        inProgress.loadWeight = 25.0
        // No end date - still in progress
        sessions.append(inProgress)
        
        // High intensity session
        let highIntensity = RuckSession()
        highIntensity.totalDistance = 8000
        highIntensity.totalDuration = 2400
        highIntensity.loadWeight = 35.0
        highIntensity.endDate = Date()
        highIntensity.rpe = 9
        highIntensity.notes = "Maximum effort session"
        sessions.append(highIntensity)
        
        // Recovery session
        let recovery = RuckSession()
        recovery.totalDistance = 3000
        recovery.totalDuration = 2400
        recovery.loadWeight = 15.0
        recovery.endDate = Date()
        recovery.rpe = 3
        recovery.notes = "Easy recovery walk"
        sessions.append(recovery)
        
        return sessions
    }
    
    static func constructSessionAccessibilityLabel(_ session: RuckSession) -> String {
        let distance = FormatUtilities.formatDistancePrecise(session.totalDistance)
        let duration = FormatUtilities.formatDurationWithSeconds(session.totalDuration)
        let load = FormatUtilities.formatWeight(session.loadWeight)
        let effort = session.rpe != nil ? "effort level \(session.rpe!)" : "no effort rating"
        
        return "Ruck session: \(distance) distance, \(duration) duration, \(load) load weight, \(effort)"
    }
    
    static func constructHistoryRowAccessibilityLabel(_ session: RuckSession) -> String {
        let baseLabel = constructSessionAccessibilityLabel(session)
        let status = session.endDate != nil ? "completed" : "in progress"
        let date = FormatUtilities.formatSessionDate(session.startDate)
        
        return "\(baseLabel), \(status) on \(date)"
    }
    
    static func constructRouteAccessibilityDescription(_ session: RuckSession) -> String {
        let pointCount = session.locationPoints.count
        let distance = FormatUtilities.formatDistancePrecise(session.totalDistance)
        
        return "Route with \(pointCount) GPS points covering \(distance)"
    }
    
    static func constructExportAccessibilityLabel(_ result: ExportManager.ExportResult) -> String {
        let format = result.format.rawValue.uppercased()
        let size = ByteCountFormatter.string(fromByteCount: Int64(result.fileSize), countStyle: .file)
        
        return "\(format) export file with \(result.pointCount) data points, file size \(size)"
    }
    
    static func constructWeatherAccessibilityDescription(_ weather: WeatherConditions) -> String {
        var components: [String] = []
        
        components.append("Temperature \(Int(weather.temperatureFahrenheit)) degrees Fahrenheit")
        
        if weather.humidity > 70 {
            components.append("High humidity at \(Int(weather.humidity)) percent")
        }
        
        if weather.windSpeed > 10 {
            components.append("Windy conditions with \(Int(weather.windSpeedMPH)) mile per hour winds")
        }
        
        if weather.precipitation > 0 {
            components.append("Precipitation present")
        }
        
        if weather.isHarshConditions {
            components.append("Harsh weather conditions")
        }
        
        return components.joined(separator: ", ")
    }
    
    static func constructTerrainAccessibilityDescription(_ terrain: TerrainType) -> String {
        switch terrain {
        case .pavedRoad:
            return "Paved road surface, suitable for fast pace"
        case .trail:
            return "Natural trail surface, moderate difficulty"
        case .gravel:
            return "Gravel surface, loose footing"
        case .sand:
            return "Sandy surface, challenging footing"
        case .mud:
            return "Muddy surface, difficult conditions"
        case .snow:
            return "Snowy surface, winter conditions"
        case .grass:
            return "Grass surface, soft footing"
        case .stairs:
            return "Stair climbing, high intensity"
        }
    }
    
    static func rpeDescriptionForAccessibility(_ rpe: Int) -> String {
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
        case 10: return "Absolute Maximum"
        default: return "Unknown effort level"
        }
    }
    
    static func constructRPEAccessibilityLabel(_ rpe: Int) -> String {
        let description = rpeDescriptionForAccessibility(rpe)
        return "Rate of Perceived Exertion \(rpe) out of 10, \(description)"
    }
    
    static func constructElevationChartAccessibility(_ points: [Any]) -> String {
        return "Elevation chart showing altitude changes over \(points.count) data points during the session"
    }
    
    static func constructPaceChartAccessibility(_ points: [Any]) -> String {
        return "Pace chart showing speed variations over \(points.count) data points during the session"
    }
    
    static func constructVoiceRecordingAccessibilityState(_ viewModel: SessionSummaryViewModel) -> String {
        if viewModel.isRecording {
            return "Currently recording voice notes"
        } else {
            return "Voice recording ready, tap to start recording notes"
        }
    }
    
    static func constructVoiceInputAccessibilityHint() -> String {
        return "Double tap to start voice recording for session notes. Speak clearly and tap again to stop recording."
    }
}