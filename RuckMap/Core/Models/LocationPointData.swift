import Foundation
import CoreLocation

/// Sendable data structure for transferring location point data across actor boundaries
public struct LocationPointData: Sendable {
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let horizontalAccuracy: Double
    public let verticalAccuracy: Double
    public let speed: Double
    public let course: Double
    public let isKeyPoint: Bool
    
    public init(
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
    
    /// Create from CLLocation
    public init(from location: CLLocation, isKeyPoint: Bool = false) {
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = location.speed
        self.course = location.course
        self.isKeyPoint = isKeyPoint
    }
}