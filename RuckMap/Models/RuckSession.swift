import Foundation
import SwiftData

@Model
final class RuckSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var totalDistance: Double // meters
    var totalDuration: TimeInterval
    var loadWeight: Double // kg
    var totalCalories: Double
    var averagePace: Double // min/km
    var elevationGain: Double // meters
    var elevationLoss: Double // meters
    var rpe: Int? // Rating of Perceived Exertion (1-10)
    var notes: String?
    var voiceNoteURL: URL?
    
    @Relationship(deleteRule: .cascade)
    var locationPoints: [LocationPoint]
    
    @Relationship(deleteRule: .cascade)
    var terrainSegments: [TerrainSegment]
    
    @Relationship(deleteRule: .cascade)
    var weatherConditions: WeatherConditions?
    
    init() {
        self.id = UUID()
        self.startDate = Date()
        self.totalDistance = 0
        self.totalDuration = 0
        self.loadWeight = 0
        self.totalCalories = 0
        self.averagePace = 0
        self.elevationGain = 0
        self.elevationLoss = 0
        self.locationPoints = []
        self.terrainSegments = []
    }
    
    convenience init(loadWeight: Double) {
        self.init()
        self.loadWeight = loadWeight
    }
}