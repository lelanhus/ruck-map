import Foundation
import SwiftData

enum TerrainType: String, CaseIterable, Codable {
    case pavedRoad = "paved_road"
    case trail = "trail"
    case gravel = "gravel"
    case sand = "sand"
    case mud = "mud"
    case snow = "snow"
    case stairs = "stairs"
    case grass = "grass"
    
    var displayName: String {
        switch self {
        case .pavedRoad: return "Paved Road"
        case .trail: return "Trail"
        case .gravel: return "Gravel"
        case .sand: return "Sand"
        case .mud: return "Mud"
        case .snow: return "Snow"
        case .stairs: return "Stairs"
        case .grass: return "Grass"
        }
    }
    
    var terrainFactor: Double {
        switch self {
        case .pavedRoad: return 1.0
        case .trail: return 1.2
        case .gravel: return 1.3
        case .sand: return 1.5
        case .mud: return 1.8
        case .snow: return 2.1
        case .stairs: return 1.8
        case .grass: return 1.2
        }
    }
    
    var icon: String {
        switch self {
        case .pavedRoad: return "road.lanes"
        case .trail: return "figure.hiking"
        case .gravel: return "circle.grid.3x3.fill"
        case .sand: return "beach.umbrella"
        case .mud: return "cloud.rain"
        case .snow: return "snowflake"
        case .stairs: return "stairs"
        case .grass: return "leaf"
        }
    }
}

@Model
final class TerrainSegment {
    var startTime: Date
    var endTime: Date
    var terrainTypeRaw: String
    var grade: Double // percentage
    var confidence: Double // 0.0 to 1.0
    var isManuallySet: Bool
    
    var terrainType: TerrainType {
        get { TerrainType(rawValue: terrainTypeRaw) ?? .pavedRoad }
        set { terrainTypeRaw = newValue.rawValue }
    }
    
    init(
        startTime: Date,
        endTime: Date,
        terrainType: TerrainType,
        grade: Double,
        confidence: Double = 0.8,
        isManuallySet: Bool = false
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.terrainTypeRaw = terrainType.rawValue
        self.grade = grade
        self.confidence = confidence
        self.isManuallySet = isManuallySet
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}