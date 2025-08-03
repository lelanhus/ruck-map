import Foundation

/**
 # Migration Guide: CalorieCalculator + TerrainDetector Integration
 
 ## Overview
 
 This guide helps migrate from Session 6's static terrain factors to Session 7's dynamic
 terrain detection integration with real-time calorie calculation updates.
 
 ## What's New in Session 7
 
 ### Enhanced Terrain Factors
 - Updated terrain factors based on biomechanical research
 - Grade-compensated terrain factors for more accuracy
 - Real-time terrain factor updates during tracking
 
 ### Swift 6 Concurrency
 - Actor-based isolation for thread safety
 - Async streams for terrain factor monitoring
 - Structured concurrency for coordinated updates
 
 ### Error Handling
 - Graceful fallbacks for terrain detection failures
 - Robust error recovery mechanisms
 - Performance monitoring and optimization
 
 ## Migration Steps
 
 ### Step 1: Update TerrainType Usage
 
 **Before (Session 6):**
 ```swift
 let terrainMultiplier = TerrainDifficultyMultiplier(from: terrain).rawValue
 ```
 
 **After (Session 7):**
 ```swift
 let terrainFactor = terrain.terrainFactor
 // Or for dynamic updates:
 let terrainFactor = await terrainDetector.getTerrainFactor()
 ```
 
 ### Step 2: Update CalorieCalculator Integration
 
 **Before (Session 6):**
 ```swift
 calorieCalculator.startContinuousCalculation(
     bodyWeight: bodyWeight,
     loadWeight: loadWeight,
     locationProvider: locationProvider,
     weatherProvider: weatherProvider
 )
 ```
 
 **After (Session 7):**
 ```swift
 calorieCalculator.startContinuousCalculation(
     bodyWeight: bodyWeight,
     loadWeight: loadWeight,
     locationProvider: locationProvider,
     weatherProvider: weatherProvider,
     terrainFactorProvider: { await terrainDetector.getEnhancedTerrainFactor(grade: grade) }
 )
 ```
 
 ### Step 3: Add Real-time Terrain Monitoring
 
 **New in Session 7:**
 ```swift
 Task {
     for await (factor, confidence, terrainType) in terrainDetector.terrainFactorStream() {
         await calorieCalculator.updateTerrainFactor(factor)
         
         if confidence > 0.8 {
             print("High-confidence terrain: \(terrainType.displayName)")
         }
     }
 }
 ```
 
 ### Step 4: Update Error Handling
 
 **Before (Session 6):**
 ```swift
 // Limited error handling
 ```
 
 **After (Session 7):**
 ```swift
 do {
     let result = try await calorieCalculator.calculateCalories(with: parameters)
 } catch {
     await terrainDetector.handleDetectionFailure(error)
 }
 ```
 
 ## Backward Compatibility
 
 ### Legacy API Support
 The Session 6 API remains functional for existing code:
 
 ```swift
 // This still works in Session 7
 calorieCalculator.startContinuousCalculation(
     bodyWeight: bodyWeight,
     loadWeight: loadWeight,
     locationProvider: locationProvider,
     weatherProvider: weatherProvider
 )
 ```
 
 ### Gradual Migration
 You can migrate incrementally:
 
 1. **Phase 1**: Update terrain factor values (immediate benefit)
 2. **Phase 2**: Add terrain factor provider (better accuracy)
 3. **Phase 3**: Add real-time monitoring (full Session 7 features)
 
 ## Common Migration Patterns
 
 ### Pattern 1: Simple Terrain Factor Update
 
 **Before:**
 ```swift
 class OldTrackingManager {
     func updateCalories() {
         let terrainMultiplier = 1.2 // Static trail factor
         // Use static factor in calculations
     }
 }
 ```
 
 **After:**
 ```swift
 class NewTrackingManager {
     let terrainDetector = TerrainDetector()
     
     func updateCalories() async {
         let terrainFactor = await terrainDetector.getTerrainFactor()
         // Use dynamic factor in calculations
     }
 }
 ```
 
 ### Pattern 2: Enhanced LocationTrackingManager
 
 **Before:**
 ```swift
 class LocationTrackingManager {
     func startCalorieTracking() {
         // Static terrain handling
         let terrain = getCurrentTerrain() // Manual or approximate
         let factor = TerrainDifficultyMultiplier(from: terrain).rawValue
         // Use in calorie calculation
     }
 }
 ```
 
 **After:**
 ```swift
 class LocationTrackingManager {
     func startCalorieTracking() {
         // Dynamic terrain handling with real-time updates
         startTerrainFactorMonitoring()
         
         calorieCalculator.startContinuousCalculation(
             // ... other parameters
             terrainFactorProvider: { [weak self] in
                 await self?.terrainDetector.getEnhancedTerrainFactor(grade: grade) ?? 1.2
             }
         )
     }
     
     private func startTerrainFactorMonitoring() {
         Task {
             for await (factor, confidence, terrainType) in terrainDetector.terrainFactorStream() {
                 await calorieCalculator.updateTerrainFactor(factor)
             }
         }
     }
 }
 ```
 
 ## Updated Terrain Factor Values
 
 ### Session 6 → Session 7 Changes
 
 | Terrain | Session 6 | Session 7 | Change | Reason |
 |---------|-----------|-----------|--------|--------|
 | Pavement | 1.0 | 1.0 | None | Baseline remains |
 | Trail | 1.2 | 1.2 | None | Research confirmed |
 | Gravel | 1.3 | 1.3 | None | Validated |
 | Sand | 1.8 | 2.1 | +0.3 | Research updated |
 | Mud | 1.85 | 1.8 | -0.05 | Rounded down |
 | Snow | 1.5 | 2.5 | +1.0 | 6" snow research |
 | Stairs | 2.0 | 2.0 | None | Validated |
 | Grass | 1.25 | 1.2 | -0.05 | Simplified |
 
 ## Testing Migration
 
 ### Unit Tests Update
 
 **Before:**
 ```swift
 func testTerrainFactors() {
     XCTAssertEqual(TerrainType.sand.terrainFactor, 1.8)
 }
 ```
 
 **After:**
 ```swift
 @Test("Updated terrain factors")
 func testTerrainFactors() {
     #expect(TerrainType.sand.terrainFactor == 2.1)
     #expect(TerrainType.snow.terrainFactor == 2.5)
 }
 ```
 
 ### Integration Tests
 
 **New in Session 7:**
 ```swift
 @Test("Real-time terrain factor updates")
 func testRealTimeTerrainUpdates() async throws {
     let calculator = CalorieCalculator()
     let detector = TerrainDetector()
     
     await detector.setManualTerrain(.trail)
     let trailResult = try await calculator.calculateCalories(with: parameters)
     
     await detector.setManualTerrain(.sand)
     await calculator.updateTerrainFactor(await detector.getTerrainFactor())
     
     #expect(calculator.currentTerrainFactor == 2.1)
 }
 ```
 
 ## Performance Considerations
 
 ### Memory Usage
 - Session 7 adds terrain detection history (bounded to 100 entries)
 - Calorie calculation history remains bounded to 1000 entries
 - No significant memory impact for normal usage
 
 ### CPU Usage
 - Terrain detection adds minimal CPU overhead
 - Real-time updates are efficient with async streams
 - Battery optimization mode available for extended sessions
 
 ### Battery Impact
 - Terrain detection can be optimized for battery life
 - Motion sensor sampling rate adjustable
 - Automatic fallbacks reduce sensor usage when needed
 
 ## Troubleshooting
 
 ### Common Issues
 
 #### Issue: Terrain factor not updating
 **Symptoms:** Calorie calculations don't reflect terrain changes
 **Solution:**
 ```swift
 // Ensure terrain factor provider is set
 calorieCalculator.startContinuousCalculation(
     // ... parameters
     terrainFactorProvider: terrainFactorProvider // Don't forget this!
 )
 
 // Or manually update
 await calorieCalculator.updateTerrainFactor(newFactor)
 ```
 
 #### Issue: Low terrain detection confidence
 **Symptoms:** Frequent fallbacks to default terrain
 **Solution:**
 ```swift
 // Check sensor availability
 if !terrainDetector.isDetecting {
     await terrainDetector.startDetection()
 }
 
 // Use manual override for known terrain
 terrainDetector.setManualTerrain(.knownTerrain)
 ```
 
 #### Issue: Performance degradation
 **Symptoms:** App feels slower during tracking
 **Solution:**
 ```swift
 // Enable battery optimization
 terrainDetector.setBatteryOptimizedMode(true)
 
 // Reduce update frequency if needed
 // (Built into the system automatically)
 ```
 
 ## Best Practices
 
 ### 1. Always Handle Async Operations
 ```swift
 // Good
 let terrainFactor = await terrainDetector.getTerrainFactor()
 
 // Avoid blocking calls
 ```
 
 ### 2. Use Error Handling
 ```swift
 do {
     let result = try await calorieCalculator.calculateCalories(with: parameters)
 } catch {
     // Handle gracefully
     await terrainDetector.handleDetectionFailure(error)
 }
 ```
 
 ### 3. Monitor Terrain Confidence
 ```swift
 if terrainDetector.confidence < 0.7 {
     // Consider manual override or fallback
 }
 ```
 
 ### 4. Optimize for Battery Life
 ```swift
 // For long sessions
 terrainDetector.setBatteryOptimizedMode(true)
 ```
 
 ## Support and Resources
 
 ### Documentation
 - `TerrainCalorieIntegrationDocumentation.swift` - Comprehensive system docs
 - `CalorieCalculationDocumentation.swift` - Calorie calculation details
 - Unit and integration tests for examples
 
 ### Testing
 - `TerrainCalorieIntegrationTests.swift` - Integration test examples
 - `TerrainCaloriePerformanceTests.swift` - Performance benchmarks
 
 ### Migration Checklist
 
 - [ ] Update terrain factor values in existing code
 - [ ] Add terrain factor provider to CalorieCalculator calls
 - [ ] Implement real-time terrain monitoring
 - [ ] Add error handling for terrain detection failures
 - [ ] Update unit tests with new terrain factor values
 - [ ] Add integration tests for dynamic terrain updates
 - [ ] Test performance with battery optimization
 - [ ] Validate calorie calculation accuracy with new factors
 */

// MARK: - Migration Helper Functions

extension CalorieCalculator {
    
    /// Convenience method for migrating from Session 6 static terrain factors
    /// to Session 7 dynamic terrain detection
    func migrateToTerrainDetectionIntegration(
        terrainDetector: TerrainDetector,
        bodyWeight: Double,
        loadWeight: Double,
        locationProvider: @escaping @Sendable () async -> (CLLocation?, Double?, TerrainType?),
        weatherProvider: @escaping @Sendable () async -> WeatherData?
    ) {
        // Use the new enhanced API with terrain factor provider
        self.startContinuousCalculation(
            bodyWeight: bodyWeight,
            loadWeight: loadWeight,
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            terrainFactorProvider: {
                // Get enhanced terrain factor with grade compensation
                let (_, grade, _) = await locationProvider()
                return await terrainDetector.getEnhancedTerrainFactor(grade: grade ?? 0)
            }
        )
    }
}

extension TerrainDetector {
    
    /// Helper method to validate migration from static to dynamic terrain factors
    func validateMigrationAccuracy(staticFactor: Double, terrainType: TerrainType) async -> Bool {
        let dynamicFactor = await getTerrainFactor()
        let expectedFactor = terrainType.terrainFactor
        
        // Validate that dynamic factor matches expected value
        let dynamicAccurate = abs(dynamicFactor - expectedFactor) < 0.01
        
        // Check if static factor needs updating
        let staticAccurate = abs(staticFactor - expectedFactor) < 0.01
        
        if !staticAccurate {
            print("Migration needed: Static factor \(staticFactor) should be \(expectedFactor) for \(terrainType.displayName)")
        }
        
        return dynamicAccurate && staticAccurate
    }
}