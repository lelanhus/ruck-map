import Foundation
import SwiftData

@Model
final class WeatherConditions {
    var timestamp: Date
    var temperature: Double // Celsius
    var humidity: Double // percentage (0-100)
    var windSpeed: Double // m/s
    var windDirection: Double // degrees
    var precipitation: Double // mm/hr
    var pressure: Double // hPa
    var weatherDescription: String?
    var conditionCode: String? // WeatherKit condition code
    
    @Relationship(inverse: \RuckSession.weatherConditions)
    var session: RuckSession?
    
    init(
        timestamp: Date = Date(),
        temperature: Double,
        humidity: Double,
        windSpeed: Double = 0,
        windDirection: Double = 0,
        precipitation: Double = 0,
        pressure: Double = 1013.25
    ) {
        self.timestamp = timestamp
        self.temperature = temperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.precipitation = precipitation
        self.pressure = pressure
    }
    
    var temperatureFahrenheit: Double {
        temperature * 9/5 + 32
    }
    
    var windSpeedMPH: Double {
        windSpeed * 2.237
    }
    
    var apparentTemperature: Double {
        // Wind chill formula for temperatures below 10°C and wind > 4.8 km/h
        let windKmh = windSpeed * 3.6
        if temperature <= 10 && windKmh > 4.8 {
            return 13.12 + 0.6215 * temperature - 11.37 * pow(windKmh, 0.16) + 0.3965 * temperature * pow(windKmh, 0.16)
        }
        
        // Heat index formula for temperatures above 27°C
        if temperature >= 27 {
            let t = temperatureFahrenheit
            let h = humidity
            let heatIndex = -42.379 + 2.04901523 * t + 10.14333127 * h
                - 0.22475541 * t * h - 0.00683783 * t * t
                - 0.05481717 * h * h + 0.00122874 * t * t * h
                + 0.00085282 * t * h * h - 0.00000199 * t * t * h * h
            return (heatIndex - 32) * 5/9 // Convert back to Celsius
        }
        
        return temperature
    }
    
    var isHarshConditions: Bool {
        return temperature < -5 || temperature > 35 ||
               windSpeed > 15 || // > 54 km/h
               precipitation > 10 // Heavy rain
    }
    
    var temperatureAdjustmentFactor: Double {
        // Based on LCDA algorithm temperature adjustments
        if temperature < -5 {
            return 1.15
        } else if temperature < 5 {
            return 1.05
        } else if temperature > 25 {
            return 1.05
        } else if temperature > 30 {
            return 1.15
        }
        return 1.0
    }
    
    var weatherSeverityScore: Double {
        var score = 1.0
        
        // Temperature stress
        if temperature < -10 || temperature > 40 {
            score += 0.3
        } else if temperature < 0 || temperature > 35 {
            score += 0.2
        } else if temperature < 5 || temperature > 30 {
            score += 0.1
        }
        
        // Wind factor
        if windSpeed > 20 {
            score += 0.3
        } else if windSpeed > 15 {
            score += 0.2
        } else if windSpeed > 10 {
            score += 0.1
        }
        
        // Precipitation
        if precipitation > 15 {
            score += 0.3
        } else if precipitation > 5 {
            score += 0.2
        } else if precipitation > 0 {
            score += 0.1
        }
        
        return min(score, 2.0) // Cap at 2.0
    }
}