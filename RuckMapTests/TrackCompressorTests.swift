import XCTest
import CoreLocation
@testable import RuckMap

final class TrackCompressorTests: XCTestCase {
    var trackCompressor: TrackCompressor!
    
    override func setUp() async throws {
        try await super.setUp()
        trackCompressor = TrackCompressor()
    }
    
    override func tearDown() async throws {
        trackCompressor = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Compression Tests
    
    func testEmptyTrackCompression() async {
        let points: [LocationPoint] = []
        let compressed = await trackCompressor.compress(points: points)
        XCTAssertTrue(compressed.isEmpty)
    }
    
    func testSinglePointCompression() async {
        let points = [createLocationPoint(lat: 40.7128, lon: -74.0060, elevation: 10)]
        let compressed = await trackCompressor.compress(points: points)
        XCTAssertEqual(compressed.count, 1)
        XCTAssertTrue(compressed[0].isKeyPoint)
    }
    
    func testTwoPointCompression() async {
        let points = [
            createLocationPoint(lat: 40.7128, lon: -74.0060, elevation: 10),
            createLocationPoint(lat: 40.7130, lon: -74.0062, elevation: 12)
        ]
        let compressed = await trackCompressor.compress(points: points)
        XCTAssertEqual(compressed.count, 2)
        XCTAssertTrue(compressed[0].isKeyPoint)
        XCTAssertTrue(compressed[1].isKeyPoint)
    }
    
    func testStraightLineCompression() async {
        // Create a straight line of points
        var points: [LocationPoint] = []
        for i in 0..<10 {
            let point = createLocationPoint(
                lat: 40.7128 + Double(i) * 0.001,
                lon: -74.0060,
                elevation: 10
            )
            points.append(point)
        }
        
        let compressed = await trackCompressor.compress(points: points, epsilon: 5.0)
        
        // Should compress to just start and end points
        XCTAssertEqual(compressed.count, 2)
        XCTAssertEqual(compressed[0].latitude, points[0].latitude)
        XCTAssertEqual(compressed[1].latitude, points[9].latitude)
    }
    
    func testZigzagTrackCompression() async {
        // Create a zigzag pattern that should preserve more points
        var points: [LocationPoint] = []
        for i in 0..<10 {
            let lat = 40.7128 + Double(i) * 0.001
            let lon = -74.0060 + (i % 2 == 0 ? 0.001 : -0.001)
            let point = createLocationPoint(lat: lat, lon: lon, elevation: 10)
            points.append(point)
        }
        
        let compressed = await trackCompressor.compress(points: points, epsilon: 5.0)
        
        // Should preserve more points due to direction changes
        XCTAssertGreaterThan(compressed.count, 2)
        XCTAssertLessThan(compressed.count, points.count)
    }
    
    // MARK: - Elevation Preservation Tests
    
    func testElevationChangePreservation() async {
        var points: [LocationPoint] = []
        let elevations = [10.0, 15.0, 25.0, 30.0, 20.0, 10.0] // Significant elevation changes
        
        for (i, elevation) in elevations.enumerated() {
            let point = createLocationPoint(
                lat: 40.7128 + Double(i) * 0.001,
                lon: -74.0060,
                elevation: elevation
            )
            points.append(point)
        }
        
        let compressed = await trackCompressor.compress(
            points: points,
            epsilon: 10.0, // Large epsilon to test elevation preservation
            preserveElevationChanges: true,
            elevationThreshold: 3.0
        )
        
        // Should preserve points with significant elevation changes
        XCTAssertGreaterThan(compressed.count, 2)
        
        // Verify elevation extrema are preserved
        let maxElevation = compressed.map { $0.bestAltitude }.max()
        let minElevation = compressed.map { $0.bestAltitude }.min()
        XCTAssertEqual(maxElevation, 30.0)
        XCTAssertEqual(minElevation, 10.0)
    }
    
    func testElevationPreservationDisabled() async {
        var points: [LocationPoint] = []
        let elevations = [10.0, 15.0, 25.0, 30.0, 20.0, 10.0]
        
        for (i, elevation) in elevations.enumerated() {
            let point = createLocationPoint(
                lat: 40.7128 + Double(i) * 0.001,
                lon: -74.0060,
                elevation: elevation
            )
            points.append(point)
        }
        
        let compressed = await trackCompressor.compress(
            points: points,
            epsilon: 10.0,
            preserveElevationChanges: false
        )
        
        // Should compress more aggressively when elevation preservation is disabled
        XCTAssertEqual(compressed.count, 2) // Just start and end
    }
    
    // MARK: - Performance Tests
    
    func testLargeTrackCompression() async {
        // Create a large track with 10,000 points
        var points: [LocationPoint] = []
        for i in 0..<10000 {
            let lat = 40.7128 + Double(i) * 0.0001 + sin(Double(i) * 0.01) * 0.001
            let lon = -74.0060 + Double(i) * 0.0001 + cos(Double(i) * 0.01) * 0.001
            let elevation = 10.0 + sin(Double(i) * 0.05) * 20.0
            let point = createLocationPoint(lat: lat, lon: lon, elevation: elevation)
            points.append(point)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = await trackCompressor.compressWithResult(points: points, epsilon: 5.0)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Verify compression
        XCTAssertLessThan(result.compressedCount, result.originalCount)
        XCTAssertGreaterThan(result.compressionRatio, 0.1) // At least 10% compression
        XCTAssertLessThan(result.compressionRatio, 0.9) // At most 90% compression
        
        // Verify performance (should complete within 10 seconds)
        XCTAssertLessThan(endTime - startTime, 10.0)
        
        print("Compressed \(result.originalCount) points to \(result.compressedCount) in \(String(format: "%.3f", endTime - startTime))s")
    }
    
    // MARK: - Douglas-Peucker Algorithm Tests
    
    func testDouglasPeuckerAccuracy() async {
        // Create a track with known characteristics
        let points = [
            createLocationPoint(lat: 0.0, lon: 0.0, elevation: 0),
            createLocationPoint(lat: 0.001, lon: 0.0, elevation: 0),
            createLocationPoint(lat: 0.002, lon: 0.001, elevation: 0), // Deviation point
            createLocationPoint(lat: 0.003, lon: 0.0, elevation: 0),
            createLocationPoint(lat: 0.004, lon: 0.0, elevation: 0)
        ]
        
        // With small epsilon, should preserve deviation point
        let compressed1 = await trackCompressor.compress(points: points, epsilon: 1.0)
        XCTAssertGreaterThan(compressed1.count, 2)
        
        // With large epsilon, should compress to endpoints
        let compressed2 = await trackCompressor.compress(points: points, epsilon: 200.0)
        XCTAssertEqual(compressed2.count, 2)
    }
    
    // MARK: - Key Point Detection Tests
    
    func testTurnPointDetection() async {
        // Create a track with a sharp turn
        let points = [
            createLocationPoint(lat: 40.7128, lon: -74.0060, elevation: 10),
            createLocationPoint(lat: 40.7130, lon: -74.0060, elevation: 10), // Going north
            createLocationPoint(lat: 40.7132, lon: -74.0060, elevation: 10),
            createLocationPoint(lat: 40.7134, lon: -74.0062, elevation: 10), // Turn east
            createLocationPoint(lat: 40.7134, lon: -74.0064, elevation: 10),
            createLocationPoint(lat: 40.7134, lon: -74.0066, elevation: 10)
        ]
        
        let compressed = await trackCompressor.compress(points: points, epsilon: 5.0)
        
        // Should preserve the turn point
        XCTAssertGreaterThan(compressed.count, 2)
        
        // Verify key points are marked
        let keyPointCount = compressed.filter { $0.isKeyPoint }.count
        XCTAssertEqual(keyPointCount, compressed.count)
    }
    
    func testSpeedChangeDetection() async {
        var points: [LocationPoint] = []
        let speeds = [1.0, 1.0, 1.0, 5.0, 5.0, 1.0, 1.0] // Speed change in middle
        
        for (i, speed) in speeds.enumerated() {
            var point = createLocationPoint(
                lat: 40.7128 + Double(i) * 0.001,
                lon: -74.0060,
                elevation: 10
            )
            point.speed = speed
            points.append(point)
        }
        
        let compressed = await trackCompressor.compress(points: points, epsilon: 10.0)
        
        // Should preserve points where speed changes significantly
        XCTAssertGreaterThan(compressed.count, 2)
    }
    
    // MARK: - Validation Tests
    
    func testCompressionValidation() async {
        // Create a realistic track
        var points: [LocationPoint] = []
        var totalElevationGain = 0.0
        
        for i in 0..<100 {
            let elevation = 10.0 + sin(Double(i) * 0.1) * 10.0
            if i > 0 {
                let previousElevation = 10.0 + sin(Double(i - 1) * 0.1) * 10.0
                if elevation > previousElevation {
                    totalElevationGain += elevation - previousElevation
                }
            }
            
            let point = createLocationPoint(
                lat: 40.7128 + Double(i) * 0.0001,
                lon: -74.0060 + Double(i) * 0.0001,
                elevation: elevation
            )
            points.append(point)
        }
        
        let compressed = await trackCompressor.compress(points: points, epsilon: 5.0)
        let validation = await trackCompressor.validateCompressionResult(points, compressed)
        
        XCTAssertTrue(validation.isValid)
        XCTAssertLessThan(validation.elevationErrorPercentage, 5.0)
        XCTAssertLessThan(validation.distanceErrorPercentage, 2.0)
    }
    
    // MARK: - Compression Result Tests
    
    func testCompressionResultMetrics() async {
        var points: [LocationPoint] = []
        for i in 0..<50 {
            let point = createLocationPoint(
                lat: 40.7128 + Double(i) * 0.001,
                lon: -74.0060,
                elevation: 10
            )
            points.append(point)
        }
        
        let result = await trackCompressor.compressWithResult(points: points, epsilon: 5.0)
        
        XCTAssertEqual(result.originalCount, 50)
        XCTAssertLessThan(result.compressedCount, 50)
        XCTAssertGreaterThan(result.compressionRatio, 0.0)
        XCTAssertLessThanOrEqual(result.compressionRatio, 1.0)
        XCTAssertGreaterThan(result.preservedKeyPoints, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createLocationPoint(lat: Double, lon: Double, elevation: Double) -> LocationPoint {
        return LocationPoint(
            timestamp: Date(),
            latitude: lat,
            longitude: lon,
            altitude: elevation,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.0,
            course: 0.0
        )
    }
}