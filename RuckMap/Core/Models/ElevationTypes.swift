//
//  ElevationTypes.swift
//  RuckMap
//
//  Created by Leland Husband on 8/2/25.
//

import Foundation

/// Configuration options for elevation tracking
public enum ElevationConfiguration: String, CaseIterable, Sendable {
    case precise = "Precise (±1m)"
    case balanced = "Balanced (±3m)"
    case batterySaver = "Battery Saver (±5m)"
    
    var updateInterval: TimeInterval {
        switch self {
        case .precise: return 1.0
        case .balanced: return 2.0
        case .batterySaver: return 5.0
        }
    }
    
    var minElevationChange: Double {
        switch self {
        case .precise: return 0.5
        case .balanced: return 1.0
        case .batterySaver: return 2.0
        }
    }
    
    var kalmanProcessNoise: Double {
        switch self {
        case .precise: return 0.01
        case .balanced: return 0.05
        case .batterySaver: return 0.1
        }
    }
    
    var kalmanMeasurementNoise: Double {
        switch self {
        case .precise: return 0.1
        case .balanced: return 0.2
        case .batterySaver: return 0.5
        }
    }
}

/// Elevation data with sensor fusion results
public struct ElevationData: Sendable {
    public let fusedElevation: Double
    public let gpsElevation: Double
    public let barometricRelativeAltitude: Double?
    public let confidence: Double // 0-1
    public let timestamp: Date
    public let grade: Double?
    
    public init(
        fusedElevation: Double,
        gpsElevation: Double,
        barometricRelativeAltitude: Double?,
        confidence: Double,
        timestamp: Date,
        grade: Double?
    ) {
        self.fusedElevation = fusedElevation
        self.gpsElevation = gpsElevation
        self.barometricRelativeAltitude = barometricRelativeAltitude
        self.confidence = confidence
        self.timestamp = timestamp
        self.grade = grade
    }
}