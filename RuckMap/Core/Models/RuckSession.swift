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
    var maxElevation: Double // meters
    var minElevation: Double // meters
    var averageGrade: Double // percentage
    var maxGrade: Double // percentage
    var minGrade: Double // percentage
    var elevationAccuracy: Double // average accuracy in meters
    var barometerDataPoints: Int // number of barometric readings
    var rpe: Int? // Rating of Perceived Exertion (1-10)
    var notes: String?
    var voiceNoteURL: URL?
    var createdAt: Date
    var modifiedAt: Date
    var syncStatus: String // For offline sync management
    var version: Int // For conflict resolution
    
    // Real-time tracking properties
    var distance: Double = 0 // alias for totalDistance
    var currentLatitude: Double?
    var currentLongitude: Double?
    var currentElevation: Double = 0
    var currentGrade: Double = 0
    var currentPace: Double = 0
    
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
        self.maxElevation = 0
        self.minElevation = 0
        self.averageGrade = 0
        self.maxGrade = 0
        self.minGrade = 0
        self.elevationAccuracy = 0
        self.barometerDataPoints = 0
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
    
    /// Total elevation change (gain + loss)
    var totalElevationChange: Double {
        elevationGain + elevationLoss
    }
    
    /// Net elevation change (gain - loss)
    var netElevationChange: Double {
        elevationGain - elevationLoss
    }
    
    /// Elevation range (max - min)
    var elevationRange: Double {
        maxElevation - minElevation
    }
    
    /// Updates elevation metrics from location points using enhanced grade calculation
    func updateElevationMetrics() async {
        guard !locationPoints.isEmpty else { return }
        
        var maxElev: Double = locationPoints.first?.bestAltitude ?? 0
        var minElev: Double = locationPoints.first?.bestAltitude ?? 0
        var accuracySum: Double = 0
        var accuracyCount: Int = 0
        var barometerCount: Int = 0
        let gradeResults: [Double] = []
        
        // Process each point for basic metrics
        for i in 0..<locationPoints.count {
            let point = locationPoints[i]
            let elevation = point.bestAltitude
            
            // Update min/max
            maxElev = max(maxElev, elevation)
            minElev = min(minElev, elevation)
            
            // Track accuracy
            if let accuracy = point.elevationAccuracy {
                accuracySum += accuracy
                accuracyCount += 1
            }
            
            // Count barometer data points
            if point.barometricAltitude != nil {
                barometerCount += 1
            }
            
            // Grade calculations will be handled by LocationTrackingManager
        }
        
        // Update session properties
        // Elevation gain/loss will be calculated by LocationTrackingManager
        self.maxElevation = maxElev
        self.minElevation = minElev
        self.elevationAccuracy = accuracyCount > 0 ? accuracySum / Double(accuracyCount) : 0
        self.barometerDataPoints = barometerCount
        
        if !gradeResults.isEmpty {
            self.averageGrade = gradeResults.reduce(0, +) / Double(gradeResults.count)
            self.maxGrade = gradeResults.max() ?? 0
            self.minGrade = gradeResults.min() ?? 0
        }
    }
    
    /// Updates elevation metrics synchronously (for backward compatibility)
    func updateElevationMetricsSync() {
        // Simplified version without async for now
        guard !locationPoints.isEmpty else { return }
        
        var maxElev: Double = locationPoints.first?.bestAltitude ?? 0
        var minElev: Double = locationPoints.first?.bestAltitude ?? 0
        
        for point in locationPoints {
            let elevation = point.bestAltitude
            maxElev = max(maxElev, elevation)
            minElev = min(minElev, elevation)
        }
        
        self.maxElevation = maxElev
        self.minElevation = minElev
    }
    
    /// Calculates enhanced grade statistics for the entire session
    func calculateEnhancedGradeStatistics() async -> (averageGrade: Double, maxGrade: Double, minGrade: Double, gradeVariability: Double)? {
        guard locationPoints.count >= 2 else { return nil }
        
        // Grade calculations will be done by LocationTrackingManager
        // This is a simplified implementation for now
        // Return current stored values
        return (averageGrade, maxGrade, minGrade, 0)
    }
    
    /// Determines if the session has high-quality elevation data
    var hasHighQualityElevationData: Bool {
        return barometerDataPoints > locationPoints.count / 2 && // At least 50% barometric coverage
               elevationAccuracy <= 2.0 && // Average accuracy within 2 meters
               locationPoints.count > 10 // Sufficient data points
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