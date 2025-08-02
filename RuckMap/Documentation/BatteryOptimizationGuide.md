# Battery Optimization Guide

## Overview

The RuckMap app has been optimized to achieve **<10% battery usage per hour** during active tracking while maintaining GPS accuracy within 2% on known routes. This guide explains the optimization features and how to use them effectively.

## Optimization Levels

### 1. Maximum Performance (12-18%/hour)
- **Best accuracy**: GPS Best for Navigation
- **Highest update frequency**: 10Hz GPS, 5Hz motion
- **Use case**: Short activities requiring maximum precision
- **Recommended for**: <1 hour activities, competitive events

### 2. Balanced (8-12%/hour) 
- **Good accuracy**: GPS Best
- **Moderate frequency**: 2Hz GPS, 5Hz motion
- **Adaptive optimizations**: Enabled
- **Use case**: Regular training activities
- **Recommended for**: 1-3 hour activities

### 3. Battery Saver (5-8%/hour)
- **Reduced accuracy**: GPS Nearest 10 meters
- **Lower frequency**: 0.5Hz GPS, 2Hz motion
- **Motion-based suppression**: Enabled
- **Use case**: Long training sessions
- **Recommended for**: 3-6 hour activities

### 4. Ultra Low Power (2-5%/hour)
- **Basic accuracy**: GPS 100 meters
- **Minimal frequency**: 0.1Hz GPS, 2Hz motion
- **Significant location changes**: Enabled when stationary
- **Use case**: Ultra-long activities
- **Recommended for**: >6 hour activities, overnight rucks

## Key Optimizations

### Adaptive GPS Management
- **Smart frequency adjustment**: Reduces GPS updates during steady-state movement
- **Movement pattern detection**: Optimizes settings based on walking/running speed
- **Battery-aware configurations**: Automatically adjusts based on battery level

### Significant Location Changes
- **Stationary detection**: Switches to low-power mode when not moving for >2 minutes
- **Automatic resumption**: Returns to normal tracking when movement is detected
- **Battery savings**: Up to 70% reduction in power usage during rest periods

### Motion-Based Optimization
- **Location update suppression**: Reduces unnecessary GPS fixes when stationary
- **Kalman filtering**: Improves location accuracy while reducing update frequency
- **Sensor fusion**: Combines GPS with motion data for better tracking

### Session Duration Optimization
- **Auto ultra-low power**: Automatically enables after 2 hours of tracking
- **Progressive optimization**: Gradually reduces power usage as session continues
- **Long-term sustainability**: Maintains basic tracking for 12+ hour activities

## Usage Recommendations

### Automatic Mode (Recommended)
```swift
// Enable auto-optimization (default)
locationTrackingManager.setAutoOptimization(true)

// Start tracking with balanced optimization
locationTrackingManager.startTracking(with: session)
```

### Manual Control
```swift
// Set specific optimization level
locationTrackingManager.setBatteryOptimizationLevel(.batterySaver)

// Check current usage
let usage = locationTrackingManager.getBatteryUsageEstimate()

// Get optimization recommendations
let recommendations = locationTrackingManager.getOptimizationRecommendations()
```

### Monitoring
```swift
// Get comprehensive report
let report = locationTrackingManager.getBatteryOptimizationReport()

// Debug information
let debug = locationTrackingManager.getDebugInfo()
```

## Expected Battery Usage

| Activity Duration | Optimization Level | Battery Usage | GPS Accuracy |
|------------------|-------------------|---------------|--------------|
| <1 hour | Maximum Performance | 12-18%/hour | ±1-3 meters |
| 1-3 hours | Balanced | 8-12%/hour | ±3-5 meters |
| 3-6 hours | Battery Saver | 5-8%/hour | ±5-10 meters |
| 6+ hours | Ultra Low Power | 2-5%/hour | ±10-50 meters |

## Activity-Specific Settings

### Short Training Runs (<2 hours)
- **Level**: Balanced or Maximum Performance
- **Features**: Full motion tracking, high-frequency GPS
- **Expected usage**: 8-15%/hour

### Long Training Rucks (2-6 hours)
- **Level**: Battery Saver
- **Features**: Motion-based optimization, reduced sensor frequency
- **Expected usage**: 5-8%/hour

### Ultra-Long Events (6+ hours)
- **Level**: Ultra Low Power
- **Features**: Significant location changes, minimal sensor usage
- **Expected usage**: 2-5%/hour

### Overnight Rucks (12+ hours)
- **Level**: Ultra Low Power + Manual optimizations
- **Features**: Maximum power savings, basic position tracking
- **Expected usage**: 1-3%/hour

## Battery Health Indicators

The app provides real-time battery health status:

- 🟢 **Optimal**: Usage ≤ target, good battery level
- 🟡 **Above Target**: Usage > target but manageable
- 🟡 **High Usage**: Significantly above target
- 🟠 **Low Battery**: <20% battery remaining
- 🔴 **Critical Battery**: <10% battery remaining

## Troubleshooting

### High Battery Usage
1. Check current optimization level
2. Review active optimizations count
3. Consider switching to Battery Saver mode
4. Enable auto-optimization if disabled

### Poor GPS Accuracy
1. Temporarily switch to higher performance mode
2. Check GPS signal strength and environment
3. Verify motion sensors are functioning
4. Consider environmental factors (buildings, trees)

### Auto-Optimization Not Working
1. Verify auto-optimization is enabled
2. Check battery monitoring permissions
3. Ensure location services are properly configured
4. Review debug information for configuration details

## Advanced Configuration

### Custom Optimization Profiles
Create custom profiles for specific use cases:

```swift
// Create custom configuration
let customConfig = GPSConfiguration(
    accuracy: kCLLocationAccuracyNearestTenMeters,
    distanceFilter: 25.0,
    updateFrequency: 3.0,
    activityType: .fitness
)
```

### Performance Monitoring
Track optimization effectiveness:

```swift
// Export metrics history
let metrics = batteryOptimizationManager.exportMetricsHistory()

// Monitor battery usage trends
let currentUsage = batteryOptimizationManager.currentBatteryUsage
let targetUsage = batteryOptimizationManager.targetBatteryUsage
```

## Testing and Validation

### Performance Tests
The app includes comprehensive performance tests to ensure optimizations work correctly:

- Battery usage estimation accuracy
- GPS configuration optimization
- Motion sensor efficiency
- Long session handling

### Real-World Validation
Test optimizations with:
- Known routes for accuracy verification
- Various activity durations
- Different battery levels
- Multiple device orientations

## Best Practices

1. **Use auto-optimization** for most activities
2. **Monitor battery status** during long sessions
3. **Test settings** before important events
4. **Consider external battery** for ultra-long activities
5. **Update iOS regularly** for latest power management features

## Future Enhancements

Planned optimizations:
- Machine learning-based prediction
- Weather-based adjustments
- Route complexity analysis
- Crowd-sourced optimization data

---

For technical implementation details, see the source code documentation in:
- `AdaptiveGPSManager.swift`
- `BatteryOptimizationManager.swift`
- `MotionLocationManager.swift`
- `ElevationManager.swift`