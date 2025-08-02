# Rucking Calorie Algorithm Feature Specification

## Feature Overview

### Elevator Pitch
For military personnel and fitness enthusiasts who ruck regularly, RuckMap's Advanced Calorie Algorithm is a scientifically-validated energy expenditure calculation system that provides laboratory-grade accuracy through multi-sensor fusion and machine learning personalization, unlike competitors (RUCKR, Apple Health, Garmin) which use generic population-based formulas with 20-50% error rates.

### Core Value Proposition
- **50% more accurate than RUCKR** through LCDA base algorithm and sensor fusion
- **Personalized to individual metabolism** with ML-based calibration
- **Real-time adaptation** to terrain, fatigue, and environmental conditions
- **Military-validated** using latest load carriage research

## User Personas

### Primary Persona: Active Duty Soldier "Mike"
- **Demographics**: 25-35 years old, male, physically fit
- **Goals**: Track training progress, meet Army standards, optimize performance
- **Pain Points**: Current apps underestimate effort, no fatigue tracking, poor terrain detection
- **Technology**: iPhone 14 Pro, Apple Watch Series 8

### Secondary Persona: Recreational Rucker "Sarah"
- **Demographics**: 30-45 years old, female, fitness enthusiast
- **Goals**: Accurate calorie tracking for weight management, training improvement
- **Pain Points**: Generic formulas don't account for her body composition, no personalization
- **Technology**: iPhone 15, Apple Watch Ultra

### Tertiary Persona: GORUCK Event Participant "James"
- **Demographics**: 35-50 years old, male, weekend warrior
- **Goals**: Prepare for events, track cumulative fatigue, optimize recovery
- **Pain Points**: No apps track multi-hour events accurately, fatigue accumulation ignored
- **Technology**: iPhone 13, Apple Watch Series 7

## Functional Requirements

### MVP Phase 1: Core Algorithm Implementation

#### FR1.1: Base Calorie Calculation Engine
**User Story**: As a rucker, I want accurate base calorie calculations so that I can track my energy expenditure reliably.

**Acceptance Criteria**:
- Implements LCDA walking equation: E = (1.44 + 1.94S + 0.24S²) × BW
- Supports speed range: 0.5-6.0 mph (0.22-2.68 m/s)
- Accounts for total weight (body + load)
- Calculates metabolic rate in kcal/min with ±10% accuracy

**Technical Implementation**:
```swift
func calculateBaseMetabolicRate(
    speed: Double,        // m/s
    bodyWeight: Double,   // kg
    loadWeight: Double    // kg
) -> Double
```

#### FR1.2: GPS + Barometer Elevation Fusion
**User Story**: As a rucker on hilly terrain, I want accurate elevation tracking so that grade calculations reflect my actual effort.

**Acceptance Criteria**:
- Fuses GPS altitude with barometric pressure readings
- Achieves ±1 meter elevation accuracy (vs ±30m GPS-only)
- Calculates instantaneous grade with 0.5% precision
- Smooths elevation data using Kalman filtering

**Technical Implementation**:
```swift
class ElevationFusionEngine {
    func fuseElevationData(
        gpsAltitude: Double,
        barometricPressure: Double,
        lastKnownElevation: Double
    ) -> FusedElevation
}
```

#### FR1.3: Grade-Adjusted Energy Expenditure
**User Story**: As a rucker climbing hills, I want the app to accurately account for uphill/downhill effort.

**Acceptance Criteria**:
- Applies grade multipliers from -20% to +20% grade
- Uses military-validated grade coefficients
- Accounts for eccentric muscle loading on downhills
- Updates calculations every 1 second

**Grade Multiplier Table**:
| Grade | Multiplier | Basis |
|-------|------------|-------|
| -20% | 0.85 | Eccentric loading |
| -10% | 0.92 | Reduced effort |
| 0% | 1.00 | Baseline |
| +10% | 1.45 | Increased effort |
| +20% | 2.10 | Steep climb |

#### FR1.4: Basic Terrain Detection
**User Story**: As a rucker on different surfaces, I want the app to detect terrain type so calories reflect surface difficulty.

**Acceptance Criteria**:
- Detects 4 basic terrain types using accelerometer variance
- Applies validated terrain multipliers
- Updates terrain classification every 10 seconds
- Provides manual override option

**Terrain Multipliers**:
```swift
enum TerrainType: Double {
    case pavement = 1.0
    case trail = 1.2
    case sand = 1.8
    case snow = 1.5
}
```

#### FR1.5: Real-Time Calorie Display
**User Story**: As a rucker, I want to see my calorie burn in real-time so I can monitor my effort.

**Acceptance Criteria**:
- Displays current burn rate (kcal/min)
- Shows total calories burned
- Updates every second during activity
- Persists data if app backgrounds

### MVP Phase 2: iPhone/Apple Watch Sensor Fusion

#### FR2.1: Dual-Device Motion Analysis
**User Story**: As a rucker with both iPhone and Apple Watch, I want the app to use both devices for better accuracy.

**Acceptance Criteria**:
- Synchronizes data from iPhone (in pack) and Watch (on wrist)
- Detects gait patterns from combined accelerometer data
- Identifies fatigue through gait variability
- Maintains accuracy if only one device available

**Technical Implementation**:
```swift
class MotionFusionEngine {
    func analyzeGaitPattern(
        phoneAccelerometer: CMAccelerometerData,
        watchAccelerometer: CMAccelerometerData
    ) -> GaitMetrics
}
```

#### FR2.2: Heart Rate Integration
**User Story**: As a rucker, I want my heart rate data to improve calorie accuracy in varying conditions.

**Acceptance Criteria**:
- Reads continuous HR from Apple Watch
- Applies thermal correction for heat-induced elevation
- Validates effort level against motion data
- Provides HR-based fatigue indicators

**Thermal Correction Formula**:
```swift
adjustedHR = baseHR - (0.4 * (ambientTemp - 20°C))
```

#### FR2.3: Advanced Terrain Classification
**User Story**: As a rucker on mixed terrain, I want precise terrain detection for accurate calorie tracking.

**Acceptance Criteria**:
- Classifies 8+ terrain types using ML model
- Achieves 90% classification accuracy
- Considers motion patterns + elevation changes
- Updates classification every 5 seconds

**Extended Terrain Types**:
- Pavement (dry/wet)
- Packed trail
- Loose trail
- Rocky terrain
- Shallow sand
- Deep sand
- Packed snow
- Fresh snow

#### FR2.4: Fatigue Accumulation Modeling
**User Story**: As a rucker on long events, I want the app to account for increasing fatigue over time.

**Acceptance Criteria**:
- Models efficiency degradation over time
- Accounts for 8-25% metabolic cost increase
- Considers fitness level in fatigue curves
- Provides fatigue warnings at thresholds

**Fatigue Model**:
```swift
fatigueMultiplier = 1.0 + (0.08 * (duration_hours) * (intensity_factor))
```

### Post-MVP: Machine Learning Personalization

#### FR3.1: Individual Metabolic Calibration
**User Story**: As a regular rucker, I want the app to learn my personal efficiency so calculations match my actual burn.

**Acceptance Criteria**:
- Implements Bayesian learning from user data
- Calibrates using HR validation
- Achieves <5% error after 10 sessions
- Maintains privacy with on-device learning

**ML Architecture**:
```swift
class MetabolicPersonalization {
    private var priorDistribution: GaussianDistribution
    private var userObservations: [CalorieObservation]
    
    func updatePersonalModel(
        predicted: Double,
        hrValidated: Double,
        confidence: Double
    )
}
```

#### FR3.2: Adaptive Algorithm Improvement
**User Story**: As a user, I want the app to continuously improve its accuracy based on my feedback.

**Acceptance Criteria**:
- Collects user feedback on perceived effort
- Correlates with objective metrics
- Updates personal model weekly
- Provides accuracy statistics

#### FR3.3: Population Segmentation
**User Story**: As a user, I want initial estimates based on similar users while my personal model develops.

**Acceptance Criteria**:
- Segments by age, gender, fitness level
- Uses military vs civilian base rates
- Provides confidence intervals
- Transitions to personal model smoothly

## Non-Functional Requirements

### Performance Requirements
- **Calculation Latency**: <50ms per update cycle
- **Battery Impact**: <5% additional drain during 2-hour ruck
- **Memory Usage**: <50MB for algorithm and ML models
- **Offline Capability**: Full functionality without internet

### Accuracy Requirements
- **MVP Target**: <10% mean absolute error vs published research data
- **Post-MVP Target**: <5% error after personalization
- **Validation Method**: Laboratory testing with portable metabolic cart

### Platform Requirements
- **iOS Version**: 17.0+ (for latest HealthKit APIs)
- **watchOS Version**: 10.0+ (for enhanced sensors)
- **Device Support**: iPhone 12+, Apple Watch Series 6+

### Privacy & Security Requirements
- **Data Storage**: All personal data encrypted on-device
- **ML Processing**: On-device only, no cloud training
- **Health Data**: HealthKit integration with user consent
- **Data Export**: User can export/delete all personal data

## Technical Architecture

### Data Flow Architecture
```
iPhone Sensors → Sensor Fusion Engine → Base Algorithm → 
                        ↓                      ↓
Apple Watch Sensors ←→ Real-time Sync   Personalization ML
                        ↓                      ↓
                  Unified Output ← Calibrated Result
```

### Core Components

#### 1. Sensor Manager
```swift
class SensorManager {
    // Manages all device sensors
    let locationManager: CLLocationManager
    let motionManager: CMMotionManager
    let healthStore: HKHealthStore
    let barometerManager: CMAltimeter
}
```

#### 2. Fusion Engine
```swift
class FusionEngine {
    // Combines multi-sensor data
    func processElevation(...) -> FusedElevation
    func classifyTerrain(...) -> TerrainType
    func detectFatigue(...) -> FatigueLevel
}
```

#### 3. Calorie Calculator
```swift
class CalorieCalculator {
    // Core algorithm implementation
    let baseAlgorithm: LCDAAlgorithm
    let personalizer: MetabolicPersonalizer
    
    func calculateCalories(...) -> CalorieResult
}
```

#### 4. ML Personalizer
```swift
class MetabolicPersonalizer {
    // Machine learning calibration
    private let model: CreateML.Model
    
    func trainOnSession(...) 
    func getPrediction(...) -> PersonalizedRate
}
```

## Testing Strategy

### Unit Testing
- Algorithm accuracy tests with known inputs
- Sensor fusion validation tests
- ML model convergence tests
- Edge case handling (extreme grades, speeds)

### Integration Testing
- iPhone-Watch communication tests
- HealthKit data flow tests
- Background processing tests
- Power consumption tests

### Field Testing
- 50+ users across personas
- Various terrain types
- Weather conditions
- Event-length sessions (6+ hours)

### Validation Testing
- Laboratory metabolic cart comparison
- Military standard route testing
- Statistical significance analysis
- Longitudinal accuracy tracking

## Implementation Timeline

### Month 1: MVP Core
- Week 1-2: LCDA base algorithm
- Week 3: GPS/Barometer fusion
- Week 4: Basic terrain detection

### Month 2: Sensor Fusion
- Week 1-2: iPhone/Watch integration
- Week 3: Heart rate integration
- Week 4: Advanced terrain classification

### Month 3: Refinement
- Week 1-2: Fatigue modeling
- Week 3: Field testing
- Week 4: Algorithm optimization

### Month 4-6: ML Personalization
- Month 4: ML model development
- Month 5: On-device training
- Month 6: Validation and release

## Success Metrics

### Accuracy Metrics
- Mean Absolute Error: <15% (MVP), <5% (ML)
- 95th Percentile Error: <25% (MVP), <10% (ML)
- Terrain Classification: >90% accuracy

### User Metrics
- Session Completion Rate: >95%
- Accuracy Satisfaction: >4.5/5 stars
- Feature Adoption: >80% use sensor fusion

### Technical Metrics
- Calculation Latency: <50ms
- Battery Impact: <5% per 2-hour session
- Crash Rate: <0.1%

## Risk Mitigation

### Technical Risks
- **Sensor Availability**: Graceful degradation if sensors unavailable
- **Battery Drain**: Aggressive power optimization, user controls
- **ML Model Size**: Quantization and pruning for size reduction

### Accuracy Risks
- **Individual Variation**: Wide confidence intervals until calibrated
- **Extreme Conditions**: Clear communication of limitations
- **Sensor Errors**: Outlier detection and smoothing

### User Risks
- **Complexity**: Progressive disclosure, smart defaults
- **Trust**: Transparent accuracy metrics, validation badges
- **Privacy**: Clear data policies, on-device processing

## Future Enhancements

### Version 2.0
- Integration with external sensors (chest straps, foot pods)
- Social features for group rucking
- Route-specific calibration
- Predictive fatigue warnings

### Version 3.0
- Real-time coaching based on metabolic state
- Recovery time predictions
- Nutrition recommendations
- Performance optimization algorithms

## Conclusion

This specification provides a comprehensive roadmap for implementing a best-in-class rucking calorie algorithm that will significantly outperform existing solutions through:

1. **Superior scientific foundation** (LCDA vs Pandolf)
2. **Advanced sensor fusion** leveraging iPhone + Apple Watch
3. **Machine learning personalization** for individual accuracy
4. **Continuous improvement** through user data and feedback

The phased approach allows for rapid MVP delivery while building toward industry-leading accuracy through personalization and advanced features.