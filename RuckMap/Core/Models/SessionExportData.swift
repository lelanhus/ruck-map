import Foundation

/// Data structure for exporting session data (Sendable)
public struct SessionExportData: Sendable, Codable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date?
    public let totalDistance: Double
    public let loadWeight: Double
    public let totalCalories: Double
    public let averagePace: Double
    public let elevationGain: Double
    public let elevationLoss: Double
    public let maxElevation: Double
    public let minElevation: Double
    public let elevationRange: Double
    public let averageGrade: Double
    public let maxGrade: Double
    public let minGrade: Double
    public let locationPointsCount: Int
    public let elevationAccuracy: Double
    public let barometerDataPoints: Int
    public let hasHighQualityElevationData: Bool
    public let version: Int
    public let createdAt: Date
    public let modifiedAt: Date
    
    public init(
        id: UUID,
        startDate: Date,
        endDate: Date?,
        totalDistance: Double,
        loadWeight: Double,
        totalCalories: Double,
        averagePace: Double,
        elevationGain: Double,
        elevationLoss: Double,
        maxElevation: Double,
        minElevation: Double,
        elevationRange: Double,
        averageGrade: Double,
        maxGrade: Double,
        minGrade: Double,
        locationPointsCount: Int,
        elevationAccuracy: Double,
        barometerDataPoints: Int,
        hasHighQualityElevationData: Bool,
        version: Int,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.totalDistance = totalDistance
        self.loadWeight = loadWeight
        self.totalCalories = totalCalories
        self.averagePace = averagePace
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.maxElevation = maxElevation
        self.minElevation = minElevation
        self.elevationRange = elevationRange
        self.averageGrade = averageGrade
        self.maxGrade = maxGrade
        self.minGrade = minGrade
        self.locationPointsCount = locationPointsCount
        self.elevationAccuracy = elevationAccuracy
        self.barometerDataPoints = barometerDataPoints
        self.hasHighQualityElevationData = hasHighQualityElevationData
        self.version = version
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}