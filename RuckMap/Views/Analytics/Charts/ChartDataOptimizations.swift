import Foundation
import SwiftUI

/// Advanced chart data optimization utilities for RuckMap analytics
/// Implements efficient data sampling, memory management, and performance optimizations

// MARK: - Chart Data Sampling

/// Intelligent data sampling for chart performance optimization
struct ChartDataSampler {
  
  /// Maximum data points to display in charts for optimal performance
  static let maxDataPoints = 100
  
  /// Samples data points using Douglas-Peucker algorithm for line charts
  static func sampleLineData<T: ChartDataPoint>(_ data: [T], maxPoints: Int = maxDataPoints) -> [T] {
    guard data.count > maxPoints else { return data }
    
    // Use Douglas-Peucker algorithm for optimal line simplification
    return douglasPeucker(data, epsilon: calculateOptimalEpsilon(data), maxPoints: maxPoints)
  }
  
  /// Samples data points using uniform sampling for bar charts
  static func sampleBarData<T: ChartDataPoint>(_ data: [T], maxPoints: Int = maxDataPoints) -> [T] {
    guard data.count > maxPoints else { return data }
    
    let step = Double(data.count) / Double(maxPoints)
    var sampledData: [T] = []
    
    for i in 0..<maxPoints {
      let index = Int(Double(i) * step)
      if index < data.count {
        sampledData.append(data[index])
      }
    }
    
    return sampledData
  }
  
  /// Samples data points using peak detection for preserving important features
  static func sampleWithPeakDetection<T: ChartDataPoint>(_ data: [T], maxPoints: Int = maxDataPoints) -> [T] {
    guard data.count > maxPoints else { return data }
    
    var importantPoints: Set<Int> = []
    let values = data.map { $0.chartValue }
    
    // Always include first and last points
    importantPoints.insert(0)
    importantPoints.insert(data.count - 1)
    
    // Find local maxima and minima
    for i in 1..<(data.count - 1) {
      let current = values[i]
      let previous = values[i - 1]
      let next = values[i + 1]
      
      if (current > previous && current > next) || (current < previous && current < next) {
        importantPoints.insert(i)
      }
    }
    
    var sampledData = importantPoints.sorted().map { data[$0] }
    
    // If we still have too many points, use uniform sampling on the important points
    if sampledData.count > maxPoints {
      sampledData = sampleBarData(sampledData, maxPoints: maxPoints)
    }
    
    // Fill remaining slots with uniform sampling
    while sampledData.count < maxPoints && sampledData.count < data.count {
      let step = Double(data.count) / Double(maxPoints - sampledData.count)
      for i in 0..<(maxPoints - sampledData.count) {
        let index = Int(Double(i) * step)
        if index < data.count && !importantPoints.contains(index) {
          sampledData.append(data[index])
          importantPoints.insert(index)
        }
      }
      break
    }
    
    return sampledData.sorted { $0.chartDate < $1.chartDate }
  }
  
  // MARK: - Private Helper Methods
  
  private static func douglasPeucker<T: ChartDataPoint>(_ data: [T], epsilon: Double, maxPoints: Int) -> [T] {
    guard data.count > 2 else { return data }
    
    var result: [T] = []
    douglasPeuckerRecursive(data, epsilon: epsilon, start: 0, end: data.count - 1, result: &result)
    
    // If still too many points, increase epsilon and try again
    if result.count > maxPoints {
      let newEpsilon = epsilon * Double(result.count) / Double(maxPoints)
      result = []
      douglasPeuckerRecursive(data, epsilon: newEpsilon, start: 0, end: data.count - 1, result: &result)
    }
    
    return result.sorted { $0.chartDate < $1.chartDate }
  }
  
  private static func douglasPeuckerRecursive<T: ChartDataPoint>(_ data: [T], epsilon: Double, start: Int, end: Int, result: inout [T]) {
    if end - start < 2 {
      result.append(data[start])
      if start != end {
        result.append(data[end])
      }
      return
    }
    
    var maxDistance = 0.0
    var maxIndex = start
    
    for i in (start + 1)..<end {
      let distance = perpendicularDistance(data[i], lineStart: data[start], lineEnd: data[end])
      if distance > maxDistance {
        maxDistance = distance
        maxIndex = i
      }
    }
    
    if maxDistance > epsilon {
      douglasPeuckerRecursive(data, epsilon: epsilon, start: start, end: maxIndex, result: &result)
      douglasPeuckerRecursive(data, epsilon: epsilon, start: maxIndex, end: end, result: &result)
    } else {
      result.append(data[start])
      result.append(data[end])
    }
  }
  
  private static func perpendicularDistance<T: ChartDataPoint>(_ point: T, lineStart: T, lineEnd: T) -> Double {
    let x0 = point.chartValue
    let y0 = point.chartDate.timeIntervalSince1970
    let x1 = lineStart.chartValue
    let y1 = lineStart.chartDate.timeIntervalSince1970
    let x2 = lineEnd.chartValue
    let y2 = lineEnd.chartDate.timeIntervalSince1970
    
    let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
    let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))
    
    return denominator == 0 ? 0 : numerator / denominator
  }
  
  private static func calculateOptimalEpsilon<T: ChartDataPoint>(_ data: [T]) -> Double {
    let values = data.map { $0.chartValue }
    let minValue = values.min() ?? 0
    let maxValue = values.max() ?? 0
    let range = maxValue - minValue
    
    // Epsilon should be 0.1% of the data range
    return range * 0.001
  }
}

// MARK: - Chart Data Point Protocol

/// Protocol for data points that can be optimized for chart display
protocol ChartDataPoint {
  var chartValue: Double { get }
  var chartDate: Date { get }
}

// MARK: - Memory-Efficient Chart Data Container

/// Memory-efficient container for chart data with automatic optimization
class OptimizedChartData<T: ChartDataPoint>: ObservableObject {
  @Published private(set) var displayData: [T] = []
  @Published private(set) var isOptimizing = false
  
  private var rawData: [T] = []
  private let maxDisplayPoints: Int
  private let optimizationStrategy: OptimizationStrategy
  
  enum OptimizationStrategy {
    case uniform
    case douglasPeucker
    case peakDetection
    case adaptive
  }
  
  init(maxDisplayPoints: Int = ChartDataSampler.maxDataPoints, strategy: OptimizationStrategy = .adaptive) {
    self.maxDisplayPoints = maxDisplayPoints
    self.optimizationStrategy = strategy
  }
  
  /// Updates the raw data and triggers optimization
  @MainActor
  func updateData(_ newData: [T]) async {
    guard newData != rawData else { return }
    
    rawData = newData
    
    if rawData.count <= maxDisplayPoints {
      displayData = rawData
      return
    }
    
    isOptimizing = true
    
    // Perform optimization on background thread
    let optimizedData = await withTaskGroup(of: [T].self) { group in
      group.addTask {
        return self.optimizeData(newData)
      }
      
      return await group.first(where: { _ in true }) ?? newData
    }
    
    displayData = optimizedData
    isOptimizing = false
  }
  
  private func optimizeData(_ data: [T]) -> [T] {
    switch optimizationStrategy {
    case .uniform:
      return ChartDataSampler.sampleBarData(data, maxPoints: maxDisplayPoints)
    case .douglasPeucker:
      return ChartDataSampler.sampleLineData(data, maxPoints: maxDisplayPoints)
    case .peakDetection:
      return ChartDataSampler.sampleWithPeakDetection(data, maxPoints: maxDisplayPoints)
    case .adaptive:
      return adaptiveOptimization(data)
    }
  }
  
  private func adaptiveOptimization(_ data: [T]) -> [T] {
    // Choose optimization strategy based on data characteristics
    let values = data.map { $0.chartValue }
    let variance = calculateVariance(values)
    let trend = calculateTrend(values)
    
    if variance > trend * 2 {
      // High variance data benefits from peak detection
      return ChartDataSampler.sampleWithPeakDetection(data, maxPoints: maxDisplayPoints)
    } else if trend > variance {
      // Trending data benefits from Douglas-Peucker
      return ChartDataSampler.sampleLineData(data, maxPoints: maxDisplayPoints)
    } else {
      // Stable data can use uniform sampling
      return ChartDataSampler.sampleBarData(data, maxPoints: maxDisplayPoints)
    }
  }
  
  private func calculateVariance(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    
    let mean = values.reduce(0, +) / Double(values.count)
    let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
    return variance
  }
  
  private func calculateTrend(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    
    let n = Double(values.count)
    let sumX = (0..<values.count).reduce(0) { $0 + $1 }
    let sumY = values.reduce(0, +)
    let sumXY = values.enumerated().reduce(0) { $0 + Double($1.offset) * $1.element }
    let sumX2 = (0..<values.count).reduce(0) { $0 + $1 * $1 }
    
    let slope = (n * sumXY - Double(sumX) * sumY) / (n * Double(sumX2) - Double(sumX * sumX))
    return abs(slope)
  }
}

// MARK: - Chart Performance Monitor

/// Performance monitoring for chart rendering
class ChartPerformanceMonitor: ObservableObject {
  @Published private(set) var averageRenderTime: TimeInterval = 0
  @Published private(set) var lastRenderTime: TimeInterval = 0
  @Published private(set) var renderCount: Int = 0
  
  private var renderTimes: [TimeInterval] = []
  private let maxSamples = 20
  
  /// Measures and records chart render time
  func measureRenderTime<T>(_ operation: () -> T) -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = operation()
    let renderTime = CFAbsoluteTimeGetCurrent() - startTime
    
    recordRenderTime(renderTime)
    return result
  }
  
  private func recordRenderTime(_ time: TimeInterval) {
    DispatchQueue.main.async {
      self.lastRenderTime = time
      self.renderTimes.append(time)
      self.renderCount += 1
      
      // Keep only recent samples
      if self.renderTimes.count > self.maxSamples {
        self.renderTimes.removeFirst()
      }
      
      // Calculate average
      self.averageRenderTime = self.renderTimes.reduce(0, +) / Double(self.renderTimes.count)
      
      // Log slow renders
      if time > 0.016 { // Slower than 60fps
        print("⚠️ Slow chart render: \(time * 1000)ms")
      }
    }
  }
  
  /// Resets performance metrics
  func reset() {
    renderTimes.removeAll()
    averageRenderTime = 0
    lastRenderTime = 0
    renderCount = 0
  }
}

// MARK: - Extensions for Existing Models

extension WeekData: ChartDataPoint {
  var chartValue: Double { totalDistance }
  var chartDate: Date { weekStart }
}

// MARK: - Chart Animation Optimizations

/// Provides optimized animations for charts based on accessibility settings
struct ChartAnimationProvider {
  
  /// Returns appropriate animation for chart updates
  static func chartUpdateAnimation() -> Animation? {
    if AccessibilityPreferences.shared.reduceMotion {
      return nil
    }
    
    return .easeInOut(duration: 0.3)
  }
  
  /// Returns appropriate animation for chart selection
  static func selectionAnimation() -> Animation? {
    if AccessibilityPreferences.shared.reduceMotion {
      return nil
    }
    
    return .easeInOut(duration: 0.2)
  }
  
  /// Returns appropriate animation for chart appearance
  static func appearanceAnimation() -> Animation? {
    if AccessibilityPreferences.shared.reduceMotion {
      return nil
    }
    
    return .easeOut(duration: 0.5)
  }
}

// MARK: - Accessibility Preferences Helper

/// Helper for accessing accessibility preferences
struct AccessibilityPreferences {
  static let shared = AccessibilityPreferences()
  
  var reduceMotion: Bool {
    UIAccessibility.isReduceMotionEnabled
  }
  
  var shouldUseHighContrast: Bool {
    UIAccessibility.isDarkerSystemColorsEnabled
  }
  
  var isReduceTransparencyEnabled: Bool {
    UIAccessibility.isReduceTransparencyEnabled
  }
}