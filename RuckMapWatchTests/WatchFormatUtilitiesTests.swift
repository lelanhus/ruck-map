import Testing
import Foundation
@testable import RuckMapWatch

/// Comprehensive tests for WatchFormatUtilities using Swift Testing framework
@Suite("Watch Format Utilities Tests")
struct WatchFormatUtilitiesTests {
    
    // MARK: - Distance Formatting Tests
    
    @Test("Distance formatting with auto style", arguments: [
        (0.0, "0m"),
        (50.0, "50m"),
        (999.0, "999m"),
        (1000.0, "1.00km"),
        (1500.0, "1.50km"),
        (5280.0, "5.28km")
    ])
    func distanceFormattingWithAutoStyle(distance: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDistance(distance, style: .auto)
        #expect(formatted == expected)
    }
    
    @Test("Distance formatting with meters style", arguments: [
        (0.0, "0m"),
        (123.5, "123m"),
        (999.9, "999m"),
        (1000.0, "1000m"),
        (5280.0, "5280m")
    ])
    func distanceFormattingWithMetersStyle(distance: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDistance(distance, style: .meters)
        #expect(formatted == expected)
    }
    
    @Test("Distance formatting with kilometers style", arguments: [
        (0.0, "0.00km"),
        (500.0, "0.50km"),
        (1000.0, "1.00km"),
        (2500.0, "2.50km"),
        (10000.0, "10.00km")
    ])
    func distanceFormattingWithKilometersStyle(distance: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDistance(distance, style: .kilometers)
        #expect(formatted == expected)
    }
    
    @Test("Distance formatting with precise style", arguments: [
        (0.0, "0.0m"),
        (50.5, "50.5m"),
        (99.9, "99.9m"),
        (100.0, "100m"),
        (500.0, "500m"),
        (1000.0, "1.00km"),
        (2500.0, "2.50km")
    ])
    func distanceFormattingWithPreciseStyle(distance: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDistance(distance, style: .precise)
        #expect(formatted == expected)
    }
    
    // MARK: - Pace Formatting Tests
    
    @Test("Pace formatting for valid paces", arguments: [
        (5.0, PaceUnit.perKilometer, "5:00/km"),
        (6.5, PaceUnit.perKilometer, "6:30/km"),
        (4.25, PaceUnit.perKilometer, "4:15/km"),
        (10.75, PaceUnit.perKilometer, "10:45/km")
    ])
    func paceFormattingForValidPaces(pace: Double, unit: PaceUnit, expected: String) throws {
        let formatted = WatchFormatUtilities.formatPace(pace, unit: unit)
        #expect(formatted == expected)
    }
    
    @Test("Pace formatting for mile unit", arguments: [
        (5.0, "8:03/mi"), // 5 min/km ≈ 8:03 min/mi
        (6.0, "9:39/mi")  // 6 min/km ≈ 9:39 min/mi
    ])
    func paceFormattingForMileUnit(pace: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatPace(pace, unit: .perMile)
        #expect(formatted == expected)
    }
    
    @Test("Pace formatting for invalid values", arguments: [
        (0.0, "--:--"),
        (-1.0, "--:--"),
        (Double.infinity, "--:--"),
        (Double.nan, "--:--")
    ])
    func paceFormattingForInvalidValues(pace: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatPace(pace, unit: .perKilometer)
        #expect(formatted == expected)
    }
    
    @Test("Current pace formatting from speed", arguments: [
        (0.0, "--:--"),
        (1.0, "16:40/km"), // 1 m/s ≈ 16:40 min/km
        (2.78, "6:00/km"), // 2.78 m/s ≈ 6:00 min/km (10 km/h)
        (4.17, "4:00/km")  // 4.17 m/s ≈ 4:00 min/km (15 km/h)
    ])
    func currentPaceFormattingFromSpeed(speed: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatCurrentPace(from: speed, unit: .perKilometer)
        #expect(formatted == expected)
    }
    
    // MARK: - Duration Formatting Tests
    
    @Test("Duration formatting with compact style", arguments: [
        (0.0, "0:00"),
        (30.0, "0:30"),
        (65.0, "1:05"),
        (3661.0, "1:01:01"),
        (7200.0, "2:00:00")
    ])
    func durationFormattingWithCompactStyle(duration: TimeInterval, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDuration(duration, style: .compact)
        #expect(formatted == expected)
    }
    
    @Test("Duration formatting with verbose style", arguments: [
        (0.0, "0s"),
        (30.0, "30s"),
        (65.0, "1m 5s"),
        (3661.0, "1h 1m 1s"),
        (7200.0, "2h 0m 0s")
    ])
    func durationFormattingWithVerboseStyle(duration: TimeInterval, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDuration(duration, style: .verbose)
        #expect(formatted == expected)
    }
    
    @Test("Duration formatting with hours minutes style", arguments: [
        (0.0, "0m"),
        (30.0, "0m"),
        (65.0, "1m"),
        (3661.0, "1:01"),
        (7200.0, "2:00")
    ])
    func durationFormattingWithHoursMinutesStyle(duration: TimeInterval, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDuration(duration, style: .hoursMinutes)
        #expect(formatted == expected)
    }
    
    // MARK: - Elevation Formatting Tests
    
    @Test("Elevation formatting without sign", arguments: [
        (0.0, "0m"),
        (100.5, "101m"), // Should round
        (1234.7, "1235m"),
        (-50.0, "-50m")
    ])
    func elevationFormattingWithoutSign(elevation: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatElevation(elevation, showSign: false)
        #expect(formatted == expected)
    }
    
    @Test("Elevation formatting with sign", arguments: [
        (0.0, "0m"),
        (100.5, "+101m"),
        (1234.7, "+1235m"),
        (-50.0, "-50m")
    ])
    func elevationFormattingWithSign(elevation: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatElevation(elevation, showSign: true)
        #expect(formatted == expected)
    }
    
    @Test("Elevation change formatting", arguments: [
        (0.0, "+0m"),
        (50.5, "+51m"),
        (-25.7, "-26m"),
        (100.0, "+100m")
    ])
    func elevationChangeFormatting(change: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatElevationChange(change)
        #expect(formatted == expected)
    }
    
    // MARK: - Grade Formatting Tests
    
    @Test("Grade formatting", arguments: [
        (0.0, "0.0%"),
        (0.05, "0.0%"), // Less than 0.1%
        (5.5, "5.5%"),
        (-3.2, "-3.2%"),
        (15.0, "15.0%")
    ])
    func gradeFormatting(grade: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatGrade(grade)
        #expect(formatted == expected)
    }
    
    // MARK: - Calorie Formatting Tests
    
    @Test("Calorie formatting with whole style", arguments: [
        (0.0, "0"),
        (50.7, "51"),
        (123.4, "123"),
        (999.9, "1000")
    ])
    func calorieFormattingWithWholeStyle(calories: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatCalories(calories, style: .whole)
        #expect(formatted == expected)
    }
    
    @Test("Calorie formatting with precise style", arguments: [
        (0.0, "0.0"),
        (5.7, "5.7"),
        (9.9, "9.9"),
        (10.1, "10"),
        (50.5, "51")
    ])
    func calorieFormattingWithPreciseStyle(calories: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatCalories(calories, style: .precise)
        #expect(formatted == expected)
    }
    
    @Test("Calorie formatting with unit style", arguments: [
        (0.0, "0 cal"),
        (50.7, "51 cal"),
        (123.4, "123 cal")
    ])
    func calorieFormattingWithUnitStyle(calories: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatCalories(calories, style: .withUnit)
        #expect(formatted == expected)
    }
    
    @Test("Calorie burn rate formatting", arguments: [
        (0.0, "0.0 cal/min"),
        (5.5, "5.5 cal/min"),
        (12.75, "12.8 cal/min")
    ])
    func calorieBurnRateFormatting(rate: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatCalorieBurnRate(rate)
        #expect(formatted == expected)
    }
    
    // MARK: - Heart Rate Formatting Tests
    
    @Test("Heart rate formatting", arguments: [
        (0.0, "0 BPM"),
        (72.5, "73 BPM"),
        (150.9, "151 BPM"),
        (200.0, "200 BPM")
    ])
    func heartRateFormatting(heartRate: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatHeartRate(heartRate)
        #expect(formatted == expected)
    }
    
    // MARK: - Weight Formatting Tests
    
    @Test("Weight formatting in kilograms", arguments: [
        (0.5, "500g"),
        (1.5, "1.5kg"),
        (70.0, "70.0kg"),
        (125.7, "125.7kg")
    ])
    func weightFormattingInKilograms(weight: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatWeight(weight, unit: .kilograms)
        #expect(formatted == expected)
    }
    
    @Test("Weight formatting in pounds", arguments: [
        (70.0, "154.3lb"), // 70kg ≈ 154.3lb
        (80.0, "176.4lb")  // 80kg ≈ 176.4lb
    ])
    func weightFormattingInPounds(weight: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatWeight(weight, unit: .pounds)
        #expect(formatted == expected)
    }
    
    // MARK: - Date/Time Formatting Tests
    
    @Test("Date formatting with different styles")
    func dateFormattingWithDifferentStyles() throws {
        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        
        let shortFormatted = WatchFormatUtilities.formatDate(testDate, style: .short)
        #expect(shortFormatted.contains("2022") || shortFormatted.contains("22")) // Different locales
        
        let mediumFormatted = WatchFormatUtilities.formatDate(testDate, style: .medium)
        #expect(mediumFormatted.contains("2022") || mediumFormatted.contains("Jan"))
        
        let timeOnlyFormatted = WatchFormatUtilities.formatDate(testDate, style: .timeOnly)
        #expect(timeOnlyFormatted.contains(":")) // Should contain time separator
    }
    
    @Test("Relative date formatting")
    func relativeDateFormatting() throws {
        let now = Date()
        
        // Just now
        let justNow = now.addingTimeInterval(-30) // 30 seconds ago
        let justNowFormatted = WatchFormatUtilities.formatDate(justNow, style: .relative)
        #expect(justNowFormatted == "Just now")
        
        // Minutes ago
        let minutesAgo = now.addingTimeInterval(-300) // 5 minutes ago
        let minutesFormatted = WatchFormatUtilities.formatDate(minutesAgo, style: .relative)
        #expect(minutesFormatted == "5m ago")
        
        // Hours ago
        let hoursAgo = now.addingTimeInterval(-7200) // 2 hours ago
        let hoursFormatted = WatchFormatUtilities.formatDate(hoursAgo, style: .relative)
        #expect(hoursFormatted == "2h ago")
        
        // Days ago
        let daysAgo = now.addingTimeInterval(-172800) // 2 days ago
        let daysFormatted = WatchFormatUtilities.formatDate(daysAgo, style: .relative)
        #expect(daysFormatted == "2d ago")
    }
    
    // MARK: - Large Number Formatting Tests
    
    @Test("Large number formatting", arguments: [
        (0.0, "0"),
        (500.0, "500"),
        (999.0, "999"),
        (1000.0, "1.0K"),
        (1500.0, "1.5K"),
        (999999.0, "1000.0K"),
        (1000000.0, "1.0M"),
        (2500000.0, "2.5M")
    ])
    func largeNumberFormatting(number: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatLargeNumber(number)
        #expect(formatted == expected)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test("Distance formatting with extreme values", arguments: [
        (-100.0, "-100m"), // Negative distance
        (Double.infinity, "infm"), // Infinity
        (1e10, "10000000000m") // Very large number
    ])
    func distanceFormattingWithExtremeValues(distance: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDistance(distance, style: .meters)
        #expect(formatted == expected)
    }
    
    @Test("Pace formatting with extreme values")
    func paceFormattingWithExtremeValues() throws {
        // Very large pace
        let largePaceFormatted = WatchFormatUtilities.formatPace(999.0, unit: .perKilometer)
        #expect(largePaceFormatted == "999:00/km")
        
        // Fractional seconds
        let fractionalFormatted = WatchFormatUtilities.formatPace(5.99, unit: .perKilometer)
        #expect(fractionalFormatted == "5:59/km")
    }
    
    @Test("Duration formatting with extreme values", arguments: [
        (-30.0, "0:00"), // Negative duration should be handled
        (86400.0, "24:00:00"), // 24 hours
        (90061.0, "25:01:01") // More than 24 hours
    ])
    func durationFormattingWithExtremeValues(duration: TimeInterval, expected: String) throws {
        let formatted = WatchFormatUtilities.formatDuration(max(0, duration), style: .compact)
        #expect(formatted == expected)
    }
    
    @Test("Grade formatting with extreme values", arguments: [
        (100.0, "100.0%"),
        (-50.0, "-50.0%"),
        (0.001, "0.0%") // Very small grade
    ])
    func gradeFormattingWithExtremeValues(grade: Double, expected: String) throws {
        let formatted = WatchFormatUtilities.formatGrade(grade)
        #expect(formatted == expected)
    }
    
    // MARK: - Performance and Consistency Tests
    
    @Test("Formatting consistency across multiple calls")
    func formattingConsistencyAcrossMultipleCalls() throws {
        let testValues = [100.0, 1500.0, 5000.0]
        
        for value in testValues {
            let format1 = WatchFormatUtilities.formatDistance(value, style: .auto)
            let format2 = WatchFormatUtilities.formatDistance(value, style: .auto)
            #expect(format1 == format2)
        }
        
        let testPaces = [5.0, 6.5, 10.0]
        
        for pace in testPaces {
            let format1 = WatchFormatUtilities.formatPace(pace, unit: .perKilometer)
            let format2 = WatchFormatUtilities.formatPace(pace, unit: .perKilometer)
            #expect(format1 == format2)
        }
    }
    
    @Test("Formatting performance with many operations")
    func formattingPerformanceWithManyOperations() throws {
        let iterations = 1000
        var results: [String] = []
        
        for i in 0..<iterations {
            let distance = Double(i * 10)
            let formatted = WatchFormatUtilities.formatDistance(distance, style: .auto)
            results.append(formatted)
        }
        
        #expect(results.count == iterations)
        #expect(results.first == "0m")
        #expect(results.last == "9.99km")
    }
    
    // MARK: - Locale and Internationalization Tests
    
    @Test("Number formatting consistency")
    func numberFormattingConsistency() throws {
        // Test that our formatting is consistent regardless of system locale
        let testValue = 1234.56
        
        let formatted1 = WatchFormatUtilities.formatDistance(testValue, style: .kilometers)
        let formatted2 = WatchFormatUtilities.formatDistance(testValue, style: .kilometers)
        
        #expect(formatted1 == formatted2)
        #expect(formatted1 == "1.23km") // Should use consistent decimal formatting
    }
    
    @Test("Time formatting consistency")
    func timeFormattingConsistency() throws {
        let testDuration: TimeInterval = 3665.0 // 1 hour, 1 minute, 5 seconds
        
        let formatted1 = WatchFormatUtilities.formatDuration(testDuration, style: .compact)
        let formatted2 = WatchFormatUtilities.formatDuration(testDuration, style: .compact)
        
        #expect(formatted1 == formatted2)
        #expect(formatted1 == "1:01:05")
    }
}