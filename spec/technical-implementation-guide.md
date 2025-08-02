# RuckMap Technical Implementation Guide

## Critical Code Components

### 1. Location Manager Setup

```swift
class LocationTrackingManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var trackingState: TrackingState = .stopped
    @Published var gpsAccuracy: GPSAccuracy = .poor
    
    private var locations: [CLLocation] = []
    private var lastDistanceCalculation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    func startTracking() {
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        // Start altimeter for elevation
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
                // Process altitude
            }
        }
    }
}
```

### 2. SwiftData Models

```swift
import SwiftData

@Model
final class RuckSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var totalDistance: Double // meters
    var totalDuration: TimeInterval
    var loadWeight: Double // kg
    var totalCalories: Double
    var averagePace: Double // min/km
    var elevationGain: Double // meters
    var rpe: Int?
    var notes: String?
    
    @Relationship(deleteRule: .cascade)
    var locationPoints: [LocationPoint]
    
    @Relationship(deleteRule: .cascade)
    var terrainSegments: [TerrainSegment]
    
    @Relationship(deleteRule: .cascade)
    var weatherConditions: WeatherConditions?
    
    init() {
        self.id = UUID()
        self.startDate = Date()
        self.totalDistance = 0
        self.totalDuration = 0
        self.loadWeight = 0
        self.totalCalories = 0
        self.averagePace = 0
        self.elevationGain = 0
        self.locationPoints = []
        self.terrainSegments = []
    }
}

@Model
final class LocationPoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var horizontalAccuracy: Double
    var verticalAccuracy: Double
    var speed: Double
    var course: Double
    
    init(from location: CLLocation) {
        self.timestamp = location.timestamp
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
        self.speed = location.speed
        self.course = location.course
    }
}
```

### 3. LCDA Calorie Algorithm

```swift
struct CalorieCalculator {
    struct Inputs {
        let bodyWeight: Double // kg
        let loadWeight: Double // kg
        let speed: Double // m/s
        let grade: Double // percentage
        let terrainFactor: Double // 1.0-2.1
        let temperature: Double // Celsius
        let altitude: Double // meters
    }
    
    static func calculateMetabolicRate(inputs: Inputs) -> Double {
        let W = inputs.bodyWeight
        let L = inputs.loadWeight
        let V = inputs.speed
        let G = inputs.grade / 100.0 // Convert percentage to decimal
        
        // Terrain factor (η)
        let n = inputs.terrainFactor
        
        // Base Pandolf equation
        var MR = 1.5 * W + 2.0 * (W + L) * pow(L/W, 2) + n * (W + L) * (1.5 * pow(V, 2) + 0.35 * V * G)
        
        // Temperature adjustment
        let tempAdjustment = temperatureAdjustment(temp: inputs.temperature)
        MR *= tempAdjustment
        
        // Altitude adjustment (>1500m)
        if inputs.altitude > 1500 {
            let altitudeAdjustment = 1.0 + (inputs.altitude - 1500) * 0.0001
            MR *= altitudeAdjustment
        }
        
        return MR // watts
    }
    
    static func temperatureAdjustment(temp: Double) -> Double {
        // Optimal temp is 10°C
        if temp < -5 {
            return 1.15
        } else if temp < 5 {
            return 1.05
        } else if temp > 25 {
            return 1.05
        } else if temp > 30 {
            return 1.15
        }
        return 1.0
    }
    
    static func wattsToCaloriesPerMinute(_ watts: Double) -> Double {
        // 1 watt = 0.0143 kcal/min
        return watts * 0.0143
    }
}
```

### 4. GPS Track Compression

```swift
struct GPSTrackCompressor {
    // Douglas-Peucker algorithm for GPS track simplification
    static func compress(points: [CLLocation], epsilon: Double = 5.0) -> [CLLocation] {
        guard points.count > 2 else { return points }
        
        // Find point with maximum distance from line
        var maxDistance = 0.0
        var maxIndex = 0
        
        let firstPoint = points.first!
        let lastPoint = points.last!
        
        for i in 1..<points.count - 1 {
            let distance = perpendicularDistance(
                point: points[i],
                lineStart: firstPoint,
                lineEnd: lastPoint
            )
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If max distance is greater than epsilon, recursively simplify
        if maxDistance > epsilon {
            let leftPoints = compress(
                points: Array(points[0...maxIndex]),
                epsilon: epsilon
            )
            let rightPoints = compress(
                points: Array(points[maxIndex..<points.count]),
                epsilon: epsilon
            )
            
            return leftPoints.dropLast() + rightPoints
        } else {
            return [firstPoint, lastPoint]
        }
    }
    
    private static func perpendicularDistance(
        point: CLLocation,
        lineStart: CLLocation,
        lineEnd: CLLocation
    ) -> Double {
        let A = point.coordinate.latitude - lineStart.coordinate.latitude
        let B = point.coordinate.longitude - lineStart.coordinate.longitude
        let C = lineEnd.coordinate.latitude - lineStart.coordinate.latitude
        let D = lineEnd.coordinate.longitude - lineStart.coordinate.longitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        let param = dot / lenSq
        
        var xx, yy: Double
        
        if param < 0 || (lineStart.coordinate.latitude == lineEnd.coordinate.latitude && 
                         lineStart.coordinate.longitude == lineEnd.coordinate.longitude) {
            xx = lineStart.coordinate.latitude
            yy = lineStart.coordinate.longitude
        } else if param > 1 {
            xx = lineEnd.coordinate.latitude
            yy = lineEnd.coordinate.longitude
        } else {
            xx = lineStart.coordinate.latitude + param * C
            yy = lineStart.coordinate.longitude + param * D
        }
        
        let dx = point.coordinate.latitude - xx
        let dy = point.coordinate.longitude - yy
        
        return sqrt(dx * dx + dy * dy) * 111000 // Convert to meters
    }
}
```

### 5. Real-time Metrics Display

```swift
struct ActiveRuckView: View {
    @StateObject private var trackingManager = LocationTrackingManager()
    @State private var displayMetric: DisplayMetric = .overview
    
    var body: some View {
        ZStack {
            // Map background
            RuckMapView(trackingManager: trackingManager)
                .ignoresSafeArea()
            
            VStack {
                // Metrics display
                MetricsCard(metric: displayMetric, session: trackingManager.currentSession)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                withAnimation {
                                    displayMetric = displayMetric.next()
                                }
                            }
                    )
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 40) {
                    Button(action: { trackingManager.togglePause() }) {
                        Image(systemName: trackingManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .background(Color.armyGreen)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    
                    Button(action: { trackingManager.stopTracking() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 30))
                            .frame(width: 80, height: 80)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}
```

### 6. HealthKit Integration

```swift
class HealthKitManager {
    let healthStore = HKHealthStore()
    
    func requestAuthorization() async throws {
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        let typesToRead: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }
    
    func saveRuckWorkout(session: RuckSession) async throws {
        let workout = HKWorkout(
            activityType: .walking,
            start: session.startDate,
            end: session.endDate ?? Date(),
            workoutEvents: nil,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: session.totalCalories),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: session.totalDistance),
            metadata: [
                "LoadWeight": session.loadWeight,
                "TerrainType": session.primaryTerrain,
                "RPE": session.rpe ?? 0
            ]
        )
        
        try await healthStore.save(workout)
    }
}
```

### 7. Terrain Detection

```swift
class TerrainDetector {
    private let motionManager = CMMotionManager()
    private var recentAccelerations: [Double] = []
    
    func detectTerrain(
        location: CLLocation,
        mapKit: MKMapView
    ) async -> TerrainType {
        // First check MapKit for surface hints
        let mapKitTerrain = await getMapKitTerrain(location: location, mapView: mapKit)
        
        // Then use motion data to confirm/refine
        let motionTerrain = analyzeMotionPattern()
        
        // Combine both signals
        return combineTerrain(mapKit: mapKitTerrain, motion: motionTerrain)
    }
    
    private func analyzeMotionPattern() -> TerrainType {
        // Analyze accelerometer variance
        guard recentAccelerations.count > 10 else { return .unknown }
        
        let variance = recentAccelerations.standardDeviation()
        
        if variance < 0.1 {
            return .pavedRoad
        } else if variance < 0.3 {
            return .trail
        } else if variance < 0.5 {
            return .rough
        } else {
            return .sand
        }
    }
}
```

## Key Implementation Patterns

### 1. Battery Optimization
- Use `distanceFilter` of 5-10m when moving slowly
- Reduce to 1Hz GPS updates when pace is steady
- Pause altimeter when stationary
- Batch UI updates every second

### 2. Data Persistence
- Compress GPS tracks before saving
- Store only every 5th location point for long rucks
- Use progressive JPEG for photos
- Clean up sessions older than 1 year

### 3. Sync Strategy
- Queue changes when offline
- Use incremental sync with timestamps
- Handle conflicts with "last write wins"
- Limit sync frequency to every 30 seconds

### 4. Error Recovery
- Auto-save session state every 30 seconds
- Restore incomplete sessions on launch
- Fallback to cell tower location if GPS fails
- Cache last known good values

### 5. Testing Approach
- Unit test calorie algorithm with known values
- UI test critical user flows
- Performance test with 4-hour sessions
- Memory test with 1000+ location points

This implementation guide provides the critical code patterns needed to build RuckMap's core functionality.