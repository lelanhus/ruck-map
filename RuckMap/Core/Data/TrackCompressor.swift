import Foundation
import CoreLocation
import OSLog

/// Implements Douglas-Peucker algorithm for GPS track compression with elevation preservation
actor TrackCompressor {
    private let logger = Logger(subsystem: "com.ruckmap.app", category: "TrackCompressor")
    
    struct CompressionResult: Sendable {
        let compressionRatio: Double
        let originalCount: Int
        let compressedCount: Int
        let preservedKeyPoints: Int
    }
    
    /// Compresses GPS track using Douglas-Peucker algorithm with elevation preservation
    /// - Parameters:
    ///   - points: Array of LocationPoint objects to compress
    ///   - epsilon: Tolerance for compression (meters). Smaller values = less compression
    ///   - preserveElevationChanges: Whether to preserve significant elevation changes
    ///   - elevationThreshold: Minimum elevation change to preserve (meters)
    /// - Returns: Indices of points to keep
    func compressToIndices(
        points: [LocationPoint],
        epsilon: Double = 5.0,
        preserveElevationChanges: Bool = true,
        elevationThreshold: Double = 2.0
    ) async -> [Int] {
        guard points.count > 2 else {
            logger.debug("Too few points to compress: \(points.count)")
            return Array(0..<points.count)
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Step 1: Mark key points (start, end, elevation changes, turns)
        var keyPoints = await markKeyPoints(
            points: points,
            preserveElevationChanges: preserveElevationChanges,
            elevationThreshold: elevationThreshold
        )
        
        // Step 2: Apply Douglas-Peucker algorithm
        let compressedIndices = await douglasPeucker(
            points: points,
            epsilon: epsilon,
            startIndex: 0,
            endIndex: points.count - 1
        )
        
        // Step 3: Combine key points with compressed points
        keyPoints.formUnion(compressedIndices)
        
        // Step 4: Return sorted indices
        let sortedIndices = keyPoints.sorted()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let compressionRatio = Double(sortedIndices.count) / Double(points.count)
        
        logger.info("""
            Track compression completed:
            - Original: \(points.count) points
            - Compressed: \(sortedIndices.count) points
            - Ratio: \(String(format: "%.1f", compressionRatio * 100))%
            - Epsilon: \(epsilon)m
            - Processing time: \(String(format: "%.3f", endTime - startTime))s
            """)
        
        return sortedIndices
    }
    
    /// Compresses GPS track and returns compressed points (for internal actor use)
    func compress(
        points: [LocationPoint],
        epsilon: Double = 5.0,
        preserveElevationChanges: Bool = true,
        elevationThreshold: Double = 2.0
    ) async -> [LocationPoint] {
        let indices = await compressToIndices(
            points: points,
            epsilon: epsilon,
            preserveElevationChanges: preserveElevationChanges,
            elevationThreshold: elevationThreshold
        )
        
        let compressedPoints = indices.map { points[$0] }
        
        // Mark compressed points as key points
        for point in compressedPoints {
            point.isKeyPoint = true
        }
        
        return compressedPoints
    }
    
    /// Compresses with detailed result information
    func compressWithResult(
        points: [LocationPoint],
        epsilon: Double = 5.0,
        preserveElevationChanges: Bool = true,
        elevationThreshold: Double = 2.0
    ) async -> CompressionResult {
        let originalCount = points.count
        let compressedIndices = await compressToIndices(
            points: points,
            epsilon: epsilon,
            preserveElevationChanges: preserveElevationChanges,
            elevationThreshold: elevationThreshold
        )
        
        let compressedCount = compressedIndices.count
        let compressionRatio = Double(compressedCount) / Double(originalCount)
        
        return CompressionResult(
            compressionRatio: compressionRatio,
            originalCount: originalCount,
            compressedCount: compressedCount,
            preservedKeyPoints: compressedCount
        )
    }
    
    // MARK: - Private Methods
    
    /// Marks key points that should always be preserved
    private func markKeyPoints(
        points: [LocationPoint],
        preserveElevationChanges: Bool,
        elevationThreshold: Double
    ) async -> Set<Int> {
        var keyPoints: Set<Int> = []
        
        // Always preserve first and last points
        keyPoints.insert(0)
        keyPoints.insert(points.count - 1)
        
        // Mark elevation change points
        if preserveElevationChanges {
            await markElevationChangePoints(
                points: points,
                threshold: elevationThreshold,
                keyPoints: &keyPoints
            )
        }
        
        // Mark significant turn points
        await markTurnPoints(points: points, keyPoints: &keyPoints)
        
        // Mark points with significant speed changes
        await markSpeedChangePoints(points: points, keyPoints: &keyPoints)
        
        return keyPoints
    }
    
    /// Marks points with significant elevation changes
    private func markElevationChangePoints(
        points: [LocationPoint],
        threshold: Double,
        keyPoints: inout Set<Int>
    ) async {
        guard points.count >= 3 else { return }
        
        for i in 1..<(points.count - 1) {
            let prev = points[i - 1]
            let current = points[i]
            let next = points[i + 1]
            
            let elevationChange1 = abs(current.elevationChange(to: prev))
            let elevationChange2 = abs(current.elevationChange(to: next))
            
            if elevationChange1 >= threshold || elevationChange2 >= threshold {
                keyPoints.insert(i)
            }
            
            // Mark local elevation extrema
            let prevElevation = prev.bestAltitude
            let currentElevation = current.bestAltitude
            let nextElevation = next.bestAltitude
            
            let isLocalMax = currentElevation > prevElevation && currentElevation > nextElevation
            let isLocalMin = currentElevation < prevElevation && currentElevation < nextElevation
            
            if (isLocalMax || isLocalMin) && (abs(currentElevation - prevElevation) >= threshold || abs(currentElevation - nextElevation) >= threshold) {
                keyPoints.insert(i)
            }
        }
    }
    
    /// Marks points with significant direction changes (turns)
    private func markTurnPoints(points: [LocationPoint], keyPoints: inout Set<Int>) async {
        guard points.count >= 3 else { return }
        
        let angleThreshold: Double = 30.0 // degrees
        
        for i in 1..<(points.count - 1) {
            let p1 = points[i - 1]
            let p2 = points[i]
            let p3 = points[i + 1]
            
            let angle = calculateTurnAngle(p1: p1, p2: p2, p3: p3)
            
            if abs(angle) >= angleThreshold {
                keyPoints.insert(i)
            }
        }
    }
    
    /// Marks points with significant speed changes
    private func markSpeedChangePoints(points: [LocationPoint], keyPoints: inout Set<Int>) async {
        guard points.count >= 2 else { return }
        
        let speedChangeThreshold: Double = 2.0 // m/s
        
        for i in 1..<points.count {
            let prev = points[i - 1]
            let current = points[i]
            
            let speedChange = abs(current.speed - prev.speed)
            
            if speedChange >= speedChangeThreshold {
                keyPoints.insert(i)
            }
        }
    }
    
    /// Calculates turn angle at a point
    private func calculateTurnAngle(p1: LocationPoint, p2: LocationPoint, p3: LocationPoint) -> Double {
        let bearing1 = bearing(from: p1, to: p2)
        let bearing2 = bearing(from: p2, to: p3)
        
        var angle = bearing2 - bearing1
        
        // Normalize to [-180, 180]
        while angle > 180 { angle -= 360 }
        while angle < -180 { angle += 360 }
        
        return angle
    }
    
    /// Calculates bearing between two points
    private func bearing(from: LocationPoint, to: LocationPoint) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x) * 180 / .pi
        return bearing >= 0 ? bearing : bearing + 360
    }
    
    /// Douglas-Peucker algorithm implementation
    private func douglasPeucker(
        points: [LocationPoint],
        epsilon: Double,
        startIndex: Int,
        endIndex: Int
    ) async -> Set<Int> {
        var result: Set<Int> = []
        
        // Base case
        if endIndex <= startIndex + 1 {
            result.insert(startIndex)
            result.insert(endIndex)
            return result
        }
        
        // Find the point with maximum distance from line segment
        var maxDistance = 0.0
        var maxIndex = startIndex
        
        let startPoint = points[startIndex]
        let endPoint = points[endIndex]
        
        for i in (startIndex + 1)..<endIndex {
            let distance = perpendicularDistance(
                point: points[i],
                lineStart: startPoint,
                lineEnd: endPoint
            )
            
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If max distance is greater than epsilon, recursively simplify
        if maxDistance > epsilon {
            // Recursive call for left segment
            let leftResult = await douglasPeucker(
                points: points,
                epsilon: epsilon,
                startIndex: startIndex,
                endIndex: maxIndex
            )
            
            // Recursive call for right segment
            let rightResult = await douglasPeucker(
                points: points,
                epsilon: epsilon,
                startIndex: maxIndex,
                endIndex: endIndex
            )
            
            result.formUnion(leftResult)
            result.formUnion(rightResult)
        } else {
            // If max distance is less than epsilon, keep only endpoints
            result.insert(startIndex)
            result.insert(endIndex)
        }
        
        return result
    }
    
    /// Calculates perpendicular distance from point to line segment
    private func perpendicularDistance(
        point: LocationPoint,
        lineStart: LocationPoint,
        lineEnd: LocationPoint
    ) -> Double {
        let A = point.latitude - lineStart.latitude
        let B = point.longitude - lineStart.longitude
        let C = lineEnd.latitude - lineStart.latitude
        let D = lineEnd.longitude - lineStart.longitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0 {
            // Line segment is actually a point
            return point.distance(to: lineStart)
        }
        
        let param = dot / lenSq
        
        let closestPoint: (lat: Double, lon: Double)
        
        if param < 0 {
            closestPoint = (lineStart.latitude, lineStart.longitude)
        } else if param > 1 {
            closestPoint = (lineEnd.latitude, lineEnd.longitude)
        } else {
            closestPoint = (
                lineStart.latitude + param * C,
                lineStart.longitude + param * D
            )
        }
        
        // Calculate distance using Haversine formula for better accuracy
        return haversineDistance(
            lat1: point.latitude,
            lon1: point.longitude,
            lat2: closestPoint.lat,
            lon2: closestPoint.lon
        )
    }
    
    /// Haversine distance calculation
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth's radius in meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return R * c
    }
    
    /// Validates compression result by checking elevation integrity
    func validateCompressionResult(_ original: [LocationPoint], _ compressed: [LocationPoint]) async -> ValidationResult {
        let originalElevationGain = calculateElevationGain(original)
        let compressedElevationGain = calculateElevationGain(compressed)
        
        let elevationError = abs(originalElevationGain - compressedElevationGain)
        let elevationErrorPercentage = originalElevationGain > 0 ? (elevationError / originalElevationGain) * 100 : 0
        
        let originalDistance = calculateTotalDistance(original)
        let compressedDistance = calculateTotalDistance(compressed)
        
        let distanceError = abs(originalDistance - compressedDistance)
        let distanceErrorPercentage = originalDistance > 0 ? (distanceError / originalDistance) * 100 : 0
        
        return ValidationResult(
            elevationError: elevationError,
            elevationErrorPercentage: elevationErrorPercentage,
            distanceError: distanceError,
            distanceErrorPercentage: distanceErrorPercentage,
            isValid: elevationErrorPercentage < 5.0 && distanceErrorPercentage < 2.0
        )
    }
    
    private func calculateElevationGain(_ points: [LocationPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        
        var gain = 0.0
        for i in 1..<points.count {
            let elevationChange = points[i].elevationChange(to: points[i - 1])
            if elevationChange > 0 {
                gain += elevationChange
            }
        }
        return gain
    }
    
    private func calculateTotalDistance(_ points: [LocationPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        
        var distance = 0.0
        for i in 1..<points.count {
            distance += points[i].distance(to: points[i - 1])
        }
        return distance
    }
}

// MARK: - Supporting Types

struct ValidationResult {
    let elevationError: Double
    let elevationErrorPercentage: Double
    let distanceError: Double
    let distanceErrorPercentage: Double
    let isValid: Bool
}