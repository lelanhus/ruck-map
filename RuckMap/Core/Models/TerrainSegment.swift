import Foundation
import SwiftData

enum TerrainType: String, CaseIterable, Codable, Sendable {
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
        case .pavedRoad: return 1.0  // Baseline efficiency (Pandolf standard)
        case .trail: return 1.2      // 20% increase in energy expenditure
        case .gravel: return 1.3     // 30% increase for loose surfaces
        case .sand: return 2.1       // 110% increase due to energy loss (Session 7 research)
        case .mud: return 1.8        // 80% increase for soft/sticky terrain
        case .snow: return 2.5       // 150% increase due to poor traction (Session 7: 6" snow)
        case .stairs: return 2.0     // 100% increase for vertical movement
        case .grass: return 1.2      // 20% increase similar to trails
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
    
    /// SF Symbol icon name for UI representation (alias for backward compatibility)
    var iconName: String {
        return icon
    }
    
    /// Army green design system color identifier
    var colorIdentifier: String {
        switch self {
        case .pavedRoad: return "armyGreen.secondary"
        case .trail: return "armyGreen.primary"
        case .gravel: return "armyGreen.tertiary"
        case .sand: return "armyGreen.accent"
        case .mud: return "armyGreen.dark"
        case .snow: return "armyGreen.light"
        case .stairs: return "armyGreen.bright"
        case .grass: return "armyGreen.natural"
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
    
    @Relationship(inverse: \RuckSession.terrainSegments)
    var session: RuckSession?
    
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
    
    var adjustedDifficulty: Double {
        terrainType.terrainFactor * (1.0 + max(0, grade / 100.0))
    }
    
    func overlaps(with other: TerrainSegment) -> Bool {
        !(endTime <= other.startTime || startTime >= other.endTime)
    }
}