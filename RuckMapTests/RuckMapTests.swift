import Testing
@testable import RuckMap
import SwiftData

@Suite("RuckMap Model Tests")
struct RuckMapTests {
    
    @Test("RuckSession initializes with correct defaults")
    func testRuckSessionInitialization() async throws {
        let session = RuckSession()
        
        #expect(session.totalDistance == 0)
        #expect(session.totalDuration == 0)
        #expect(session.loadWeight == 0)
        #expect(session.totalCalories == 0)
        #expect(session.averagePace == 0)
        #expect(session.elevationGain == 0)
        #expect(session.elevationLoss == 0)
        #expect(session.rpe == nil)
        #expect(session.notes == nil)
        #expect(session.locationPoints.isEmpty)
        #expect(session.terrainSegments.isEmpty)
        #expect(session.weatherConditions == nil)
    }
    
    @Test("RuckSession convenience initializer sets load weight")
    func testRuckSessionConvenienceInit() async throws {
        let loadWeight = 15.0 // kg
        let session = RuckSession(loadWeight: loadWeight)
        
        #expect(session.loadWeight == loadWeight)
    }
    
    @Test("TerrainType factors are correct")
    func testTerrainTypeFactors() async throws {
        #expect(TerrainType.pavedRoad.terrainFactor == 1.0)
        #expect(TerrainType.trail.terrainFactor == 1.2)
        #expect(TerrainType.gravel.terrainFactor == 1.3)
        #expect(TerrainType.sand.terrainFactor == 1.5)
        #expect(TerrainType.mud.terrainFactor == 1.8)
        #expect(TerrainType.snow.terrainFactor == 2.1)
        #expect(TerrainType.stairs.terrainFactor == 1.8)
        #expect(TerrainType.grass.terrainFactor == 1.2)
    }
    
    @Test("WeatherConditions temperature conversions")
    func testWeatherConditionsConversions() async throws {
        let weather = WeatherConditions(
            temperature: 20.0, // 20°C
            humidity: 50.0
        )
        
        #expect(weather.temperatureFahrenheit == 68.0)
    }
    
    @Test("WeatherConditions harsh conditions detection")
    func testHarshConditionsDetection() async throws {
        // Normal conditions
        let normalWeather = WeatherConditions(
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 5.0
        )
        #expect(!normalWeather.isHarshConditions)
        
        // Cold conditions
        let coldWeather = WeatherConditions(
            temperature: -10.0,
            humidity: 50.0
        )
        #expect(coldWeather.isHarshConditions)
        
        // Hot conditions
        let hotWeather = WeatherConditions(
            temperature: 40.0,
            humidity: 50.0
        )
        #expect(hotWeather.isHarshConditions)
        
        // High wind
        let windyWeather = WeatherConditions(
            temperature: 20.0,
            humidity: 50.0,
            windSpeed: 20.0
        )
        #expect(windyWeather.isHarshConditions)
    }
}