import SwiftUI

// MARK: - RuckMap Color Theme
/// Army Green inspired color system following iOS 18+ design guidelines
/// Prepared for iOS 26 Liquid Glass compatibility
extension Color {
    
    // MARK: - Primary Army Green Palette
    static let armyGreenPrimary = Color(red: 0.2, green: 0.3, blue: 0.2)
    static let armyGreenSecondary = Color(red: 0.3, green: 0.4, blue: 0.3)
    static let armyGreenTertiary = Color(red: 0.4, green: 0.5, blue: 0.4)
    static let armyGreenLight = Color(red: 0.5, green: 0.6, blue: 0.5)
    
    // MARK: - Weather Status Colors
    static let weatherExcellent = Color.green
    static let weatherGood = Color.blue
    static let weatherFair = Color.orange
    static let weatherPoor = Color.red
    static let weatherCritical = Color.purple
    
    // MARK: - Temperature Colors
    static let temperatureCold = Color.blue
    static let temperatureCool = Color.cyan
    static let temperatureComfortable = Color.green
    static let temperatureWarm = Color.orange
    static let temperatureHot = Color.red
    static let temperatureExtreme = Color.purple
    
    // MARK: - Weather Impact Colors
    static let weatherBeneficial = Color.green
    static let weatherNeutral = Color.blue
    static let weatherChallenging = Color.orange
    static let weatherDangerous = Color.red
    
    // MARK: - Army Green Semantic Colors
    static let ruckMapBackground = Color(UIColor.systemBackground)
    static let ruckMapSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let ruckMapTertiaryBackground = Color(UIColor.tertiarySystemBackground)
    
    static let ruckMapPrimary = armyGreenPrimary
    static let ruckMapSecondary = armyGreenSecondary
    static let ruckMapAccent = armyGreenLight
    
    // MARK: - Weather Alert Colors
    static let alertInfo = Color.blue
    static let alertWarning = Color.orange
    static let alertCritical = Color.red
    
    // MARK: - Dynamic Color Helpers
    
    /// Returns appropriate color for temperature value
    static func temperatureColor(for celsius: Double) -> Color {
        switch celsius {
        case ...(-10):
            return .temperatureExtreme
        case (-10)...0:
            return .temperatureCold
        case 0...10:
            return .temperatureCool
        case 10...25:
            return .temperatureComfortable
        case 25...35:
            return .temperatureWarm
        case 35...45:
            return .temperatureHot
        default:
            return .temperatureExtreme
        }
    }
    
    /// Returns appropriate color for weather impact level
    static func weatherImpactColor(for impact: WeatherImpactAnalysis.ImpactLevel) -> Color {
        switch impact {
        case .beneficial:
            return .weatherBeneficial
        case .neutral:
            return .weatherNeutral
        case .challenging:
            return .weatherChallenging
        case .dangerous:
            return .weatherDangerous
        }
    }
    
    /// Returns appropriate color for weather alert severity
    static func weatherAlertColor(for severity: WeatherAlertSeverity) -> Color {
        switch severity {
        case .info:
            return .alertInfo
        case .warning:
            return .alertWarning
        case .critical:
            return .alertCritical
        }
    }
}

// MARK: - iOS 26 Liquid Glass Preparation
extension Color {
    
    /// Liquid Glass compatible background with subtle transparency
    static var liquidGlassBackground: Color {
        Color(UIColor.systemBackground).opacity(0.85)
    }
    
    /// Liquid Glass compatible card background
    static var liquidGlassCard: Color {
        Color(UIColor.secondarySystemBackground).opacity(0.9)
    }
    
    /// Army green with liquid glass effect
    static var armyGreenLiquidGlass: Color {
        armyGreenPrimary.opacity(0.8)
    }
}

// MARK: - Accessibility Support
extension Color {
    
    /// High contrast version of army green for accessibility
    static var armyGreenHighContrast: Color {
        Color(red: 0.1, green: 0.2, blue: 0.1)
    }
    
    /// Ensures proper contrast for text on army green backgrounds
    static func contrastingTextColor(on backgroundColor: Color) -> Color {
        // This is a simplified implementation
        // In production, you'd calculate luminance and choose appropriate contrast
        if backgroundColor == .armyGreenPrimary || backgroundColor == .armyGreenSecondary {
            return .white
        }
        return .primary
    }
}

// MARK: - Animation Support
extension Color {
    
    /// Animated color transition for weather changes
    func weatherTransition(to newColor: Color, duration: Double = 0.3) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [self, newColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .animation(.easeInOut(duration: duration), value: newColor)
    }
}