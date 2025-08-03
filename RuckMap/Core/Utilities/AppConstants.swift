import Foundation

/// Application constants to avoid magic numbers and ensure consistency
enum AppConstants {
    
    // MARK: - Weight Configuration
    
    /// Minimum weight in pounds for load configuration
    static let minimumWeightPounds: Double = 0
    
    /// Maximum weight in pounds for load configuration  
    static let maximumWeightPounds: Double = 200
    
    /// Weight adjustment step in pounds
    static let weightAdjustmentStep: Double = 5
    
    /// Default starting weight in pounds
    static let defaultWeightPounds: Double = 35.0
    
    // MARK: - UI Configuration
    
    /// Number of recent sessions to display on home screen
    static let recentSessionsDisplayCount = 3
}