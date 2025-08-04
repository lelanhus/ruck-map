import SwiftUI
import Charts
import Foundation

// MARK: - Advanced Chart Optimizations for RuckMap Analytics

/// Advanced optimization techniques for Swift Charts in RuckMap
/// Implements performance best practices, memory management, and advanced features

// MARK: - Performance-Optimized Chart Base

/// Base class providing common performance optimizations for all RuckMap charts
struct PerformanceOptimizedChart<Data: Identifiable>: View {
    let data: [Data]
    let maxDataPoints: Int
    let enableAnimation: Bool
    let prefersReducedMotion: Bool
    
    @State private var displayData: [Data] = []
    @State private var isDataLoaded = false
    
    init(
        data: [Data],
        maxDataPoints: Int = 100,
        enableAnimation: Bool = true,
        prefersReducedMotion: Bool = false
    ) {
        self.data = data
        self.maxDataPoints = maxDataPoints
        self.enableAnimation = enableAnimation
        self.prefersReducedMotion = prefersReducedMotion
    }
    
    var body: some View {
        Group {
            if isDataLoaded {
                chartContent
            } else {
                loadingView
            }
        }
        .task {
            await loadOptimizedData()
        }
        .onChange(of: data) { _, newData in
            Task {
                await loadOptimizedData()
            }
        }
    }
    
    @ViewBuilder
    private var chartContent: some View {
        // Implemented by subclasses
        EmptyView()
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(height: 200)
            .frame(maxWidth: .infinity)
    }
    
    @MainActor
    private func loadOptimizedData() async {
        // Perform data optimization on background thread
        let optimizedData = await withTaskGroup(of: [Data].self) { group in
            group.addTask {
                return optimizeDataForDisplay()
            }
            
            return await group.first(where: { _ in true }) ?? []
        }
        
        displayData = optimizedData
        
        if enableAnimation && !prefersReducedMotion {
            withAnimation(.easeInOut(duration: 0.3)) {
                isDataLoaded = true
            }
        } else {
            isDataLoaded = true
        }
    }
    
    private func optimizeDataForDisplay() -> [Data] {
        guard data.count > maxDataPoints else { return data }
        
        // Implement intelligent sampling
        let step = Double(data.count) / Double(maxDataPoints)
        var optimizedData: [Data] = []
        
        for i in 0..<maxDataPoints {
            let index = Int(Double(i) * step)
            if index < data.count {
                optimizedData.append(data[index])
            }
        }
        
        return optimizedData
    }
}

// MARK: - Real-Time Chart with Streaming Data

/// High-performance chart for real-time data streaming during active ruck sessions
struct RealTimeSessionChart: View {
    @StateObject private var dataBuffer = CircularBuffer<SessionDataPoint>(capacity: 200)
    @State private var lastUpdateTime = Date()
    @State private var isStreaming = false
    
    let sessionId: UUID
    let updateInterval: TimeInterval = 1.0 // 1 second updates
    
    struct SessionDataPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let heartRate: Int?
        let pace: Double?
        let distance: Double
        let elevation: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Session Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(isStreaming ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(isStreaming ? "Live" : "Paused")
                        .font(.caption)
                        .foregroundStyle(isStreaming ? .green : .red)
                }
            }
            
            Chart(dataBuffer.items) { point in
                // Heart rate line
                if let heartRate = point.heartRate {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Heart Rate", heartRate),
                        series: .value("Metric", "Heart Rate")
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                // Pace line
                if let pace = point.pace, pace > 0 {
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Pace", pace),
                        series: .value("Metric", "Pace")
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                // Distance area
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Distance", point.distance)
                )
                .foregroundStyle(.green.opacity(0.3))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .minute, count: 5)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.hour().minute())
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let heartRate = value.as(Int.self) {
                            Text("\(heartRate) bpm")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisTick()
                    AxisValueLabel {
                        if let pace = value.as(Double.self) {
                            Text(formatPace(pace))
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .animation(.linear(duration: 0.1), value: dataBuffer.items.count)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2, y: 1)
        .onAppear {
            startStreaming()
        }
        .onDisappear {
            stopStreaming()
        }
    }
    
    private func startStreaming() {
        isStreaming = true
        
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            guard isStreaming else {
                timer.invalidate()
                return
            }
            
            // Simulate new data point (replace with actual session data)
            let newPoint = SessionDataPoint(
                timestamp: Date(),
                heartRate: Int.random(in: 120...180),
                pace: Double.random(in: 6.0...12.0),
                distance: dataBuffer.items.last?.distance ?? 0 + Double.random(in: 0.01...0.05),
                elevation: Double.random(in: 100...300)
            )
            
            dataBuffer.append(newPoint)
        }
    }
    
    private func stopStreaming() {
        isStreaming = false
    }
    
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Circular Buffer for Memory-Efficient Streaming

/// Memory-efficient circular buffer for streaming chart data
class CircularBuffer<T>: ObservableObject {
    @Published private(set) var items: [T] = []
    private var buffer: [T?]
    private let capacity: Int
    private var head = 0
    private var count = 0
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    func append(_ item: T) {
        buffer[head] = item
        
        if count < capacity {
            count += 1
        }
        
        head = (head + 1) % capacity
        
        // Update published array for SwiftUI
        updatePublishedItems()
    }
    
    private func updatePublishedItems() {
        var orderedItems: [T] = []
        
        if count < capacity {
            // Buffer not full, collect items in order
            for i in 0..<count {
                if let item = buffer[i] {
                    orderedItems.append(item)
                }
            }
        } else {
            // Buffer is full, reorder to maintain chronological order
            for i in 0..<capacity {
                let index = (head + i) % capacity
                if let item = buffer[index] {
                    orderedItems.append(item)
                }
            }
        }
        
        items = orderedItems
    }
    
    func clear() {
        buffer = Array(repeating: nil, count: capacity)
        items.removeAll()
        head = 0
        count = 0
    }
}

// MARK: - Advanced 3D Chart (iOS 26+)

/// Advanced 3D elevation profile chart using new iOS 26 Chart3D capabilities
@available(iOS 26.0, *)
struct ElevationProfile3DChart: View {
    let routePoints: [RoutePoint3D]
    @State private var selectedPoint: RoutePoint3D?
    @State private var cameraPosition: CameraPosition = .automatic
    
    struct RoutePoint3D: Identifiable {
        let id = UUID()
        let latitude: Double
        let longitude: Double
        let elevation: Double
        let distance: Double
        let timestamp: Date
    }
    
    enum CameraPosition {
        case automatic
        case overhead
        case side
        case perspective
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("3D Elevation Profile")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("Automatic") { cameraPosition = .automatic }
                    Button("Overhead") { cameraPosition = .overhead }
                    Button("Side View") { cameraPosition = .side }
                    Button("Perspective") { cameraPosition = .perspective }
                } label: {
                    Label("View", systemImage: "viewfinder")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            Chart3D(data: routePoints) { point in
                PointMark3D(
                    x: .value("Longitude", point.longitude),
                    y: .value("Latitude", point.latitude),
                    z: .value("Elevation", point.elevation)
                )
                .foregroundStyle(by: .value("Elevation", point.elevation))
                .symbolSize(selectedPoint?.id == point.id ? 100 : 50)
                
                // Connect points with lines
                LineMark3D(
                    x: .value("Longitude", point.longitude),
                    y: .value("Latitude", point.latitude),
                    z: .value("Elevation", point.elevation)
                )
                .foregroundStyle(Color(red: 0.18, green: 0.31, blue: 0.18))
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
            .frame(height: 300)
            .chart3DProjection(projectionFor(cameraPosition))
            .chartForegroundStyleScale(
                range: Gradient(colors: [.green, .yellow, .orange, .red])
            )
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            selectPoint(at: location, geometry: geometry, proxy: chartProxy)
                        }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: cameraPosition)
            
            // Selected point details
            if let selectedPoint = selectedPoint {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Elevation: \(selectedPoint.elevation, format: .number.precision(.fractionLength(0)))m")
                                .font(.caption.bold())
                            
                            Text("Distance: \(selectedPoint.distance / 1000.0, format: .number.precision(.fractionLength(2)))km")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Clear Selection") {
                            selectedPoint = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2, y: 1)
    }
    
    private func projectionFor(_ position: CameraPosition) -> Chart3DProjection {
        switch position {
        case .automatic:
            return .orthographic
        case .overhead:
            return .orthographic(azimuth: 0, inclination: .degrees(90))
        case .side:
            return .orthographic(azimuth: .degrees(90), inclination: .degrees(0))
        case .perspective:
            return .perspective(azimuth: .degrees(45), inclination: .degrees(30))
        }
    }
    
    private func selectPoint(at location: CGPoint, geometry: GeometryProxy, proxy: Chart3DProxy) {
        // Implementation would use Chart3DProxy to determine selected point
        // This is a placeholder for the actual 3D selection logic
        selectedPoint = routePoints.randomElement()
    }
}

// MARK: - Memory-Efficient Chart Data Manager

/// Manages chart data loading and caching for optimal memory usage
class ChartDataManager: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let cache = NSCache<NSString, AnyObject>()
    private let maxCacheSize = 50 // MB
    
    init() {
        cache.totalCostLimit = maxCacheSize * 1024 * 1024
    }
    
    /// Load chart data with intelligent caching
    func loadChartData<T: Codable>(
        for key: String,
        dataType: T.Type,
        loader: @escaping () async throws -> T
    ) async -> T? {
        
        // Check cache first
        if let cachedData = cache.object(forKey: key as NSString) as? T {
            return cachedData
        }
        
        isLoading = true
        error = nil
        
        do {
            let data = try await loader()
            
            // Cache the data
            let dataSize = MemoryLayout<T>.size
            cache.setObject(data as AnyObject, forKey: key as NSString, cost: dataSize)
            
            isLoading = false
            return data
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    /// Preload chart data in background
    func preloadChartData<T: Codable>(
        for keys: [String],
        dataType: T.Type,
        loader: @escaping (String) async throws -> T
    ) async {
        
        await withTaskGroup(of: Void.self) { group in
            for key in keys {
                group.addTask {
                    _ = await self.loadChartData(for: key, dataType: dataType) {
                        try await loader(key)
                    }
                }
            }
        }
    }
    
    /// Clear cache to free memory
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Performance Monitoring

/// Performance monitoring utilities for chart optimization
struct ChartPerformanceMonitor {
    private static var renderTimes: [String: [TimeInterval]] = [:]
    
    /// Measure chart render time
    static func measureRenderTime<T>(for chartName: String, operation: () -> T) -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        recordRenderTime(chartName: chartName, time: timeElapsed)
        
        if timeElapsed > 0.1 { // Log slow renders
            print("⚠️ Slow chart render: \(chartName) took \(timeElapsed * 1000)ms")
        }
        
        return result
    }
    
    private static func recordRenderTime(chartName: String, time: TimeInterval) {
        renderTimes[chartName, default: []].append(time)
        
        // Keep only last 10 measurements
        if var times = renderTimes[chartName], times.count > 10 {
            times.removeFirst()
            renderTimes[chartName] = times
        }
    }
    
    /// Get average render time for a chart
    static func averageRenderTime(for chartName: String) -> TimeInterval? {
        guard let times = renderTimes[chartName], !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    /// Get performance report
    static func generatePerformanceReport() -> String {
        var report = "Chart Performance Report\n"
        report += "========================\n\n"
        
        for (chartName, times) in renderTimes {
            let avgTime = times.reduce(0, +) / Double(times.count)
            let maxTime = times.max() ?? 0
            let minTime = times.min() ?? 0
            
            report += "\(chartName):\n"
            report += "  Average: \(String(format: "%.2f", avgTime * 1000))ms\n"
            report += "  Min: \(String(format: "%.2f", minTime * 1000))ms\n"
            report += "  Max: \(String(format: "%.2f", maxTime * 1000))ms\n"
            report += "  Samples: \(times.count)\n\n"
        }
        
        return report
    }
}