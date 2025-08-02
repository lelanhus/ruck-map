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
    var createdAt: Date
    var modifiedAt: Date
    var syncStatus: String // For offline sync management
    var version: Int // For conflict resolution
    
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
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.syncStatus = "pending"
        self.version = 1
        self.locationPoints = []
        self.terrainSegments = []
    }
    
    convenience init(loadWeight: Double) throws {
        self.init()
        guard loadWeight > 0 && loadWeight <= 200 else {
            throw ValidationError.invalidWeight(loadWeight)
        }
        self.loadWeight = loadWeight
    }
    
    func updateModificationDate() {
        self.modifiedAt = Date()
        self.version += 1
    }
    
    var isActive: Bool {
        endDate == nil
    }
    
    var duration: TimeInterval {
        guard let endDate = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return endDate.timeIntervalSince(startDate)
    }
}

enum ValidationError: LocalizedError {
    case invalidWeight(Double)
    case invalidDistance
    case invalidCalories
    case futureStartDate
    case invalidEndDate
    
    var errorDescription: String? {
        switch self {
        case .invalidWeight(let weight):
            return "Invalid weight: \(weight) kg. Must be between 0 and 200."
        case .invalidDistance:
            return "Distance must be non-negative."
        case .invalidCalories:
            return "Calories must be non-negative."
        case .futureStartDate:
            return "Start date cannot be in the future."
        case .invalidEndDate:
            return "End date must be after start date."
        }
    }
}