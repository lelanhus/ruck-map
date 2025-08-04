import Foundation

/// Result of terrain detection
struct DetectedTerrain: Sendable {
    let type: TerrainType
    let confidence: Double
    let grade: Double?
    let timestamp: Date
    
    init(type: TerrainType, confidence: Double, grade: Double? = nil, timestamp: Date = Date()) {
        self.type = type
        self.confidence = confidence
        self.grade = grade
        self.timestamp = timestamp
    }
}