import Foundation
import SwiftData
import CoreLocation

@Model
final class LocationPoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var horizontalAccuracy: Double
    var verticalAccuracy: Double
    var speed: Double // m/s
    var course: Double // degrees
    var barometricAltitude: Double? // meters from barometer
    var heartRate: Double? // bpm from HealthKit
    var isKeyPoint: Bool // For Douglas-Peucker compression
    
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
}