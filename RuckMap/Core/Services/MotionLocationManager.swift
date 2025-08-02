import Foundation
import CoreLocation
import CoreMotion
import Observation

// MARK: - Motion Activity Classification
enum MotionActivityType: String, CaseIterable, Sendable {
    case stationary
    case walking
    case running
    case cycling
    case automotive
    case unknown
    
    var description: String {
        switch self {
        case .stationary: return "Stationary"
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .automotive: return "Driving"
        case .unknown: return "Unknown"
        }
    }
    
    var expectedSpeed: ClosedRange<Double> {
        switch self {
        case .stationary: return 0.0...0.5
        case .walking: return 0.5...2.0
        case .running: return 2.0...6.0
        case .cycling: return 3.0...15.0
        case .automotive: return 5.0...50.0
        case .unknown: return 0.0...100.0
        }
    }
    
    var updateFrequency: TimeInterval {
        switch self {
        case .stationary: return 5.0 // Every 5 seconds when not moving
        case .walking: return 1.0 // Every second when walking
        case .running: return 0.5 // Twice per second when running
        case .cycling: return 0.5 // Twice per second when cycling
        case .automotive: return 0.3 // 3 times per second when driving
        case .unknown: return 1.0 // Default frequency
        }
    }
}

// MARK: - Attitude Data
struct AttitudeData: Sendable {
    let roll: Double
    let pitch: Double
    let yaw: Double
    
    init(from attitude: CMAttitude) {
        self.roll = attitude.roll
        self.pitch = attitude.pitch
        self.yaw = attitude.yaw
    }
}

// MARK: - Motion Data
struct MotionData: Sendable {
    let acceleration: CMAcceleration
    let rotationRate: CMRotationRate
    let attitude: AttitudeData?
    let timestamp: Date
    let motionActivity: MotionActivityType
    let confidence: Double // 0.0 to 1.0
    
    var magnitude: Double {
        sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
    }
    
    var isSignificantMotion: Bool {
        magnitude > 1.2 // Greater than gravity plus some movement
    }
}

// MARK: - Kalman Filter for Location
actor KalmanLocationFilter {
    private var isInitialized = false
    private var lastTimestamp: TimeInterval = 0
    
    // State vector: [latitude, longitude, velocity_lat, velocity_lon]
    private var state = [Double](repeating: 0, count: 4)
    private var covariance = [[Double]](repeating: [Double](repeating: 0, count: 4), count: 4)
    
    // Process noise and measurement noise
    private let processNoise: Double = 0.01
    private let measurementNoise: Double = 5.0 // meters
    
    init() {
        // Initialize covariance matrix with reasonable uncertainty
        for i in 0..<4 {
            covariance[i][i] = i < 2 ? 100.0 : 10.0 // Position uncertainty vs velocity uncertainty
        }
    }
    
    func process(location: CLLocation, motionData: MotionData?) async -> CLLocation {
        let timestamp = location.timestamp.timeIntervalSince1970
        
        if !isInitialized {
            initialize(with: location)
            lastTimestamp = timestamp
            return location
        }
        
        let deltaTime = timestamp - lastTimestamp
        guard deltaTime > 0 else { return location }
        
        // Prediction step
        predict(deltaTime: deltaTime, motionData: motionData)
        
        // Update step with GPS measurement
        update(with: location)
        
        lastTimestamp = timestamp
        
        // Create filtered location
        let filteredCoordinate = CLLocationCoordinate2D(
            latitude: state[0],
            longitude: state[1]
        )
        
        return CLLocation(
            coordinate: filteredCoordinate,
            altitude: location.altitude,
            horizontalAccuracy: min(location.horizontalAccuracy, 10.0),
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: max(0, sqrt(pow(state[2], 2) + pow(state[3], 2)) * 111000), // Convert to m/s
            timestamp: location.timestamp
        )
    }
    
    private func initialize(with location: CLLocation) {
        state[0] = location.coordinate.latitude
        state[1] = location.coordinate.longitude
        state[2] = 0 // Initial velocity lat
        state[3] = 0 // Initial velocity lon
        isInitialized = true
    }
    
    private func predict(deltaTime: TimeInterval, motionData: MotionData?) {
        // State transition matrix (constant velocity model)
        let F = [
            [1.0, 0.0, deltaTime, 0.0],
            [0.0, 1.0, 0.0, deltaTime],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0]
        ]
        
        // Predict state
        let newState = matrixVectorMultiply(F, state)
        state = newState
        
        // Process noise matrix
        let Q = createProcessNoiseMatrix(deltaTime: deltaTime)
        
        // Predict covariance: P = F * P * F^T + Q
        let FP = matrixMultiply(F, covariance)
        let FPFT = matrixMultiply(FP, transpose(F))
        covariance = matrixAdd(FPFT, Q)
    }
    
    private func update(with location: CLLocation) {
        // Measurement matrix (we observe position, not velocity)
        let H = [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0]
        ]
        
        // Measurement
        let z = [location.coordinate.latitude, location.coordinate.longitude]
        
        // Innovation
        let Hx = matrixVectorMultiply(H, state)
        let y = vectorSubtract(z, Hx)
        
        // Innovation covariance
        let HP = matrixMultiply(H, covariance)
        let HPHt = matrixMultiply(HP, transpose(H))
        let R = [[measurementNoise, 0], [0, measurementNoise]]
        let S = matrixAdd(HPHt, R)
        
        // Kalman gain
        let K = matrixMultiply(matrixMultiply(covariance, transpose(H)), matrixInverse(S))
        
        // Update state
        let Ky = matrixVectorMultiply(K, y)
        state = vectorAdd(state, Ky)
        
        // Update covariance
        let KH = matrixMultiply(K, H)
        let I = identityMatrix(size: 4)
        let IKH = matrixSubtract(I, KH)
        covariance = matrixMultiply(IKH, covariance)
    }
    
    // MARK: - Matrix Operations (Simplified)
    
    private func matrixVectorMultiply(_ matrix: [[Double]], _ vector: [Double]) -> [Double] {
        return matrix.map { row in
            zip(row, vector).map(*).reduce(0, +)
        }
    }
    
    private func matrixMultiply(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        let rows = a.count
        let cols = b[0].count
        let inner = b.count
        
        var result = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
        
        for i in 0..<rows {
            for j in 0..<cols {
                for k in 0..<inner {
                    result[i][j] += a[i][k] * b[k][j]
                }
            }
        }
        return result
    }
    
    private func transpose(_ matrix: [[Double]]) -> [[Double]] {
        let rows = matrix.count
        let cols = matrix[0].count
        var result = Array(repeating: Array(repeating: 0.0, count: rows), count: cols)
        
        for i in 0..<rows {
            for j in 0..<cols {
                result[j][i] = matrix[i][j]
            }
        }
        return result
    }
    
    private func matrixAdd(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        return zip(a, b).map { zip($0, $1).map(+) }
    }
    
    private func matrixSubtract(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        return zip(a, b).map { zip($0, $1).map(-) }
    }
    
    private func vectorAdd(_ a: [Double], _ b: [Double]) -> [Double] {
        return zip(a, b).map(+)
    }
    
    private func vectorSubtract(_ a: [Double], _ b: [Double]) -> [Double] {
        return zip(a, b).map(-)
    }
    
    private func identityMatrix(size: Int) -> [[Double]] {
        var matrix = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        for i in 0..<size {
            matrix[i][i] = 1.0
        }
        return matrix
    }
    
    private func createProcessNoiseMatrix(deltaTime: TimeInterval) -> [[Double]] {
        let dt2 = deltaTime * deltaTime
        let dt3 = dt2 * deltaTime
        let dt4 = dt3 * deltaTime
        
        let q = processNoise
        
        return [
            [dt4/4 * q, 0, dt3/2 * q, 0],
            [0, dt4/4 * q, 0, dt3/2 * q],
            [dt3/2 * q, 0, dt2 * q, 0],
            [0, dt3/2 * q, 0, dt2 * q]
        ]
    }
    
    private func matrixInverse(_ matrix: [[Double]]) -> [[Double]] {
        // Simplified 2x2 matrix inverse for innovation covariance
        guard matrix.count == 2 && matrix[0].count == 2 else {
            return matrix // Return original if not 2x2
        }
        
        let a = matrix[0][0]
        let b = matrix[0][1]
        let c = matrix[1][0]
        let d = matrix[1][1]
        
        let det = a * d - b * c
        guard abs(det) > 1e-10 else {
            return [[1, 0], [0, 1]] // Return identity if singular
        }
        
        return [
            [d / det, -b / det],
            [-c / det, a / det]
        ]
    }
    
    func reset() {
        isInitialized = false
        state = [Double](repeating: 0, count: 4)
        for i in 0..<4 {
            for j in 0..<4 {
                covariance[i][j] = 0
            }
            covariance[i][i] = i < 2 ? 100.0 : 10.0
        }
        lastTimestamp = 0
    }
}

// MARK: - Motion Location Manager Actor
@Observable
@MainActor
final class MotionLocationManager: NSObject {
    // MARK: - Published Properties
    var currentLocation: CLLocation?
    var currentMotionActivity: MotionActivityType = .unknown
    var motionConfidence: Double = 0.0
    var isMotionTracking: Bool = false
    var filteredLocation: CLLocation?
    var suppressLocationUpdates: Bool = false
    var motionPredictedLocation: CLLocation?
    
    // Motion metrics
    var accelerationMagnitude: Double = 0.0
    var rotationMagnitude: Double = 0.0
    var stationaryDuration: TimeInterval = 0.0
    var lastSignificantMotionTime: Date?
    
    // Battery optimization
    var batteryOptimizedMode: Bool = false
    var updateSuppressionCount: Int = 0
    
    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    
    private let kalmanFilter = KalmanLocationFilter()
    private var motionDataBuffer: [MotionData] = []
    private let motionBufferSize = 10
    
    // Timing and thresholds
    private let stationaryThreshold: TimeInterval = 30.0 // 30 seconds without motion
    private let significantMotionThreshold: Double = 1.5 // Acceleration threshold
    private let updateSuppressionThreshold: Int = 5 // Suppress every 5th update when stationary
    
    // Motion prediction
    private var lastMotionData: MotionData?
    private var motionPredictionEnabled = true
    
    // Adaptive GPS integration
    weak var adaptiveGPSManager: AdaptiveGPSManager?
    
    // Background queue for motion processing
    private let motionQueue = OperationQueue()
    
    override init() {
        super.init()
        setupMotionManager()
        setupMotionQueue()
    }
    
    deinit {
        // Motion updates will be stopped when stopMotionTracking is called
        // CoreMotion managers will clean up automatically
    }
    
    // MARK: - Setup Methods
    
    private func setupMotionManager() {
        motionManager.deviceMotionUpdateInterval = 0.2 // 5Hz for motion data (reduced from 10Hz)
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.gyroUpdateInterval = 0.2
        
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .utility // Reduced from userInitiated for battery savings
    }
    
    private func setupMotionQueue() {
        motionQueue.name = "MotionLocationManager.processing"
    }
    
    // MARK: - Public Methods
    
    func startMotionTracking() {
        guard !isMotionTracking else { return }
        
        isMotionTracking = true
        lastSignificantMotionTime = Date()
        
        Task {
            await kalmanFilter.reset()
        }
        
        startDeviceMotionUpdates()
        startActivityUpdates()
        
        // Start pedometer if available
        if CMPedometer.isStepCountingAvailable() {
            startPedometerUpdates()
        }
    }
    
    func stopMotionTracking() {
        guard isMotionTracking else { return }
        
        isMotionTracking = false
        
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        
        motionDataBuffer.removeAll()
    }
    
    func processLocationUpdate(_ location: CLLocation) async -> CLLocation {
        currentLocation = location
        
        // Get current motion data for filtering
        let currentMotionData = getCurrentMotionData()
        
        // Apply Kalman filtering
        let filtered = await kalmanFilter.process(location: location, motionData: currentMotionData)
        filteredLocation = filtered
        
        // Check if we should suppress this update
        if shouldSuppressLocationUpdate() {
            updateSuppressionCount += 1
            
            // Use motion prediction if available
            if let predicted = generateMotionPredictedLocation() {
                motionPredictedLocation = predicted
                return predicted
            }
            
            return filtered
        }
        
        updateSuppressionCount = 0
        return filtered
    }
    
    func setAdaptiveGPSManager(_ manager: AdaptiveGPSManager) {
        adaptiveGPSManager = manager
    }
    
    func setBatteryOptimizedMode(_ enabled: Bool) {
        batteryOptimizedMode = enabled
        
        if enabled {
            // Reduce motion update frequency for battery savings
            motionManager.deviceMotionUpdateInterval = 0.5 // 2Hz for battery mode
            motionManager.accelerometerUpdateInterval = 0.5
            motionManager.gyroUpdateInterval = 0.5
        } else {
            // Standard reduced frequency (not the original aggressive 10Hz)
            motionManager.deviceMotionUpdateInterval = 0.2 // 5Hz standard
            motionManager.accelerometerUpdateInterval = 0.2
            motionManager.gyroUpdateInterval = 0.2
        }
    }
    
    func enableMotionPrediction(_ enabled: Bool) {
        motionPredictionEnabled = enabled
    }
    
    // MARK: - Private Motion Tracking Methods
    
    private func startDeviceMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: motionQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            Task { @MainActor in
                await self.processDeviceMotion(motion)
            }
        }
    }
    
    private func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        activityManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            
            Task { @MainActor in
                self.processMotionActivity(activity)
            }
        }
    }
    
    private func startPedometerUpdates() {
        let now = Date()
        pedometer.startUpdates(from: now) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }
            
            Task { @MainActor in
                self.processPedometerData(data)
            }
        }
    }
    
    private func processDeviceMotion(_ motion: CMDeviceMotion) async {
        let motionData = MotionData(
            acceleration: motion.userAcceleration,
            rotationRate: motion.rotationRate,
            attitude: AttitudeData(from: motion.attitude),
            timestamp: Date(),
            motionActivity: currentMotionActivity,
            confidence: motionConfidence
        )
        
        // Update motion metrics
        accelerationMagnitude = motionData.magnitude
        rotationMagnitude = sqrt(
            pow(motion.rotationRate.x, 2) +
            pow(motion.rotationRate.y, 2) +
            pow(motion.rotationRate.z, 2)
        )
        
        // Check for significant motion
        if motionData.isSignificantMotion {
            lastSignificantMotionTime = Date()
            stationaryDuration = 0
        } else if let lastMotion = lastSignificantMotionTime {
            stationaryDuration = Date().timeIntervalSince(lastMotion)
        }
        
        // Add to buffer
        motionDataBuffer.append(motionData)
        if motionDataBuffer.count > motionBufferSize {
            motionDataBuffer.removeFirst()
        }
        
        lastMotionData = motionData
        
        // Update suppression state
        updateLocationSuppressionState()
    }
    
    private func processMotionActivity(_ activity: CMMotionActivity) {
        let newActivity = classifyMotionActivity(activity)
        let newConfidence = calculateConfidence(activity)
        
        if newActivity != currentMotionActivity {
            currentMotionActivity = newActivity
            motionConfidence = newConfidence
            
            // Notify adaptive GPS manager of activity change
            notifyActivityChange()
        }
    }
    
    private func processPedometerData(_ data: CMPedometerData) {
        // Additional validation for walking/running detection
        if data.numberOfSteps.intValue > 0 {
            // Enhance walking/running detection
            if currentMotionActivity == .unknown || currentMotionActivity == .stationary {
                currentMotionActivity = .walking
                motionConfidence = min(motionConfidence + 0.1, 1.0)
            }
        }
    }
    
    // MARK: - Motion Analysis Methods
    
    private func classifyMotionActivity(_ activity: CMMotionActivity) -> MotionActivityType {
        if activity.stationary {
            return .stationary
        } else if activity.walking {
            return .walking
        } else if activity.running {
            return .running
        } else if activity.cycling {
            return .cycling
        } else if activity.automotive {
            return .automotive
        } else {
            return .unknown
        }
    }
    
    private func calculateConfidence(_ activity: CMMotionActivity) -> Double {
        switch activity.confidence {
        case .low:
            return 0.3
        case .medium:
            return 0.6
        case .high:
            return 0.9
        @unknown default:
            return 0.5
        }
    }
    
    private func getCurrentMotionData() -> MotionData? {
        return lastMotionData
    }
    
    private func shouldSuppressLocationUpdate() -> Bool {
        guard isMotionTracking else { return false }
        
        // Don't suppress if we're moving significantly
        if stationaryDuration < stationaryThreshold {
            return false
        }
        
        // Don't suppress if we're in high-accuracy mode
        if let adaptiveGPS = adaptiveGPSManager,
           adaptiveGPS.isHighPerformanceMode {
            return false
        }
        
        // Suppress based on battery optimization settings
        if batteryOptimizedMode {
            return updateSuppressionCount < updateSuppressionThreshold
        }
        
        // Standard suppression logic
        return currentMotionActivity == .stationary && 
               updateSuppressionCount < updateSuppressionThreshold / 2
    }
    
    private func updateLocationSuppressionState() {
        suppressLocationUpdates = shouldSuppressLocationUpdate()
    }
    
    private func generateMotionPredictedLocation() -> CLLocation? {
        guard motionPredictionEnabled,
              let currentLoc = filteredLocation ?? currentLocation,
              let motionData = lastMotionData else {
            return nil
        }
        
        // Simple motion prediction based on current velocity and motion
        let timeDelta: TimeInterval = 1.0 // Predict 1 second ahead
        
        // Calculate predicted movement based on motion activity
        let speedEstimate = estimateSpeed(from: motionData)
        let courseEstimate = estimateCourse(from: motionData)
        
        guard speedEstimate > 0.1 else { return currentLoc } // No prediction for very slow movement
        
        // Calculate new position
        let distance = speedEstimate * timeDelta
        let newCoordinate = currentLoc.coordinate.destination(
            bearing: courseEstimate,
            distance: distance
        )
        
        return CLLocation(
            coordinate: newCoordinate,
            altitude: currentLoc.altitude,
            horizontalAccuracy: currentLoc.horizontalAccuracy * 1.5, // Reduce confidence
            verticalAccuracy: currentLoc.verticalAccuracy,
            course: courseEstimate,
            speed: speedEstimate,
            timestamp: Date()
        )
    }
    
    private func estimateSpeed(from motionData: MotionData) -> Double {
        let activityRange = motionData.motionActivity.expectedSpeed
        let motionIntensity = min(max(motionData.magnitude - 1.0, 0) / 2.0, 1.0) // Normalize motion intensity
        
        return activityRange.lowerBound + (activityRange.upperBound - activityRange.lowerBound) * motionIntensity
    }
    
    private func estimateCourse(from motionData: MotionData) -> Double {
        guard let attitude = motionData.attitude else {
            return currentLocation?.course ?? 0
        }
        
        // Use device attitude to estimate course
        let yaw = attitude.yaw * 180 / .pi
        return yaw < 0 ? yaw + 360 : yaw
    }
    
    private func notifyActivityChange() {
        // Update adaptive GPS manager with new activity
        adaptiveGPSManager?.forceConfigurationUpdate()
    }
    
    // MARK: - Debug Information
    
    var debugInfo: String {
        """
        Motion Location Manager Debug Info:
        - Motion Activity: \(currentMotionActivity.description)
        - Motion Confidence: \(String(format: "%.2f", motionConfidence))
        - Acceleration Magnitude: \(String(format: "%.3f", accelerationMagnitude))
        - Rotation Magnitude: \(String(format: "%.3f", rotationMagnitude))
        - Stationary Duration: \(String(format: "%.1f", stationaryDuration))s
        - Location Suppression: \(suppressLocationUpdates ? "ON" : "OFF")
        - Suppression Count: \(updateSuppressionCount)
        - Battery Optimized: \(batteryOptimizedMode ? "ON" : "OFF")
        - Motion Prediction: \(motionPredictionEnabled ? "ON" : "OFF")
        - Motion Tracking: \(isMotionTracking ? "ON" : "OFF")
        """
    }
}

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D {
    func destination(bearing: Double, distance: Double) -> CLLocationCoordinate2D {
        let earthRadius: Double = 6371000 // Earth's radius in meters
        
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let bearingRad = bearing * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                       cos(lat1) * sin(distance / earthRadius) * cos(bearingRad))
        
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distance / earthRadius) * cos(lat1),
                               cos(distance / earthRadius) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}