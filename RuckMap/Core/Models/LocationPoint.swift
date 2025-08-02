import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationPoint: Sendable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var horizontalAccuracy: Double
    var verticalAccuracy: Double
    var speed: Double // m/s
    var course: Double // degrees
    var barometricAltitude: Double? // meters from barometer
    var fusedAltitude: Double? // meters from Kalman-filtered sensor fusion
    var elevationAccuracy: Double? // estimated accuracy in meters
    var elevationConfidence: Double? // confidence score 0.0-1.0
    var instantaneousGrade: Double? // current grade percentage
    var pressure: Double? // barometric pressure in kPa
    var heartRate: Double? // bpm from HealthKit
    var isKeyPoint: Bool // For Douglas-Peucker compression
    
    // GPS Compression tracking properties
    var compressionIndex: Int? // Original index before compression
    var compressionError: Double? // Distance error from compression in meters
    var compressedTimestamp: Date? // When the point was compressed
    
    @Relationship(inverse: \RuckSession.locationPoints)
    var session: RuckSession?
    
    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        speed: Double,
        course: Double,
        isKeyPoint: Bool = false
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.course = course
        self.isKeyPoint = isKeyPoint
    }
    
    convenience init(from location: CLLocation, isKeyPoint: Bool = false) {
        self.init(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: max(0, location.speed), // Ensure non-negative
            course: location.course >= 0 ? location.course : 0,
            isKeyPoint: isKeyPoint
        )
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
    
    func distance(to other: LocationPoint) -> Double {
        clLocation.distance(from: other.clLocation)
    }
    
    var isAccurate: Bool {
        horizontalAccuracy <= 10.0 && horizontalAccuracy > 0
    }
    
    /// Determines if elevation data meets accuracy requirements (±1 meter target)
    var hasAccurateElevation: Bool {
        guard let accuracy = elevationAccuracy,
              let confidence = elevationConfidence else {
            return false
        }
        return accuracy <= 1.0 && confidence >= 0.7
    }
    
    /// Returns the best available altitude reading with preference order:
    /// 1. Fused altitude (if available and confident)
    /// 2. Barometric altitude (if available)
    /// 3. GPS altitude (fallback)
    var bestAltitude: Double {
        if let fused = fusedAltitude,
           let confidence = elevationConfidence,
           confidence >= 0.5 {
            return fused
        } else if let barometric = barometricAltitude {
            return barometric
        } else {
            return altitude
        }
    }
    
    /// Updates elevation data with individual values
    func updateElevationData(
        barometricAltitude: Double?,
        fusedAltitude: Double?,
        accuracy: Double?,
        confidence: Double?,
        grade: Double?,
        pressure: Double?
    ) {
        self.barometricAltitude = barometricAltitude
        self.fusedAltitude = fusedAltitude
        self.elevationAccuracy = accuracy
        self.elevationConfidence = confidence
        self.instantaneousGrade = grade
        self.pressure = pressure
    }
    
    /// Calculates elevation change to another point using best available altitude
    func elevationChange(to other: LocationPoint) -> Double {
        return other.bestAltitude - self.bestAltitude
    }
    
    /// Calculates grade percentage to another point
    func gradeTo(_ other: LocationPoint) -> Double {
        let elevationChange = elevationChange(to: other)
        let horizontalDistance = distance(to: other)
        guard horizontalDistance > 0 else { return 0.0 }
        
        let grade = (elevationChange / horizontalDistance) * 100.0
        return max(-20.0, min(20.0, grade)) // Clamp to ±20%
    }
    
    /// Returns true if this point was part of GPS compression
    func wasCompressed() -> Bool {
        return compressionIndex != nil || compressionError != nil || compressedTimestamp != nil
    }
}