# SwiftUI Performance Optimization Guide

## Overview

Performance optimization in SwiftUI is crucial for creating responsive, efficient applications. This guide covers techniques for optimizing view updates, memory usage, and rendering performance in iOS 18+.

## View Identity and Updates

### Understanding View Identity

SwiftUI uses view identity to determine when to update views. Proper identity management is critical for performance.

```swift
// ❌ Bad: Unstable identity causes unnecessary updates
ForEach(rucks) { ruck in
    RuckRow(ruck: ruck)
        .id(UUID())  // New ID every time = full redraw
}

// ✅ Good: Stable identity
ForEach(rucks) { ruck in
    RuckRow(ruck: ruck)
        .id(ruck.id)  // Stable ID = efficient updates
}
```

### Structural Identity

```swift
struct OptimizedView: View {
    let condition: Bool
    
    var body: some View {
        // ❌ Bad: Different structure = loss of state
        if condition {
            Text("Hello").font(.title)
        } else {
            Text("Hello").font(.body)
        }
        
        // ✅ Good: Same structure = preserved state
        Text("Hello")
            .font(condition ? .title : .body)
    }
}
```

## Lazy Loading Strategies

### LazyVStack and LazyHStack

```swift
struct RuckHistoryView: View {
    let rucks: [RuckSession]
    
    var body: some View {
        ScrollView {
            // ❌ Bad: Loads all views immediately
            VStack {
                ForEach(rucks) { ruck in
                    RuckDetailCard(ruck: ruck)  // All created at once
                }
            }
            
            // ✅ Good: Loads views as needed
            LazyVStack(spacing: 16) {
                ForEach(rucks) { ruck in
                    RuckDetailCard(ruck: ruck)  // Created on demand
                }
            }
        }
    }
}
```

### LazyVGrid for Large Collections

```swift
struct RuckGalleryView: View {
    let photos: [RuckPhoto]
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(photos) { photo in
                    AsyncImage(url: photo.url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 120)
                    .clipped()
                }
            }
        }
    }
}
```

## Memory Management

### Image Loading and Caching

```swift
// Custom async image with caching
struct CachedAsyncImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var isLoading = false
    
    static let cache = NSCache<NSURL, UIImage>()
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                ProgressView()
            } else {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .task {
            await loadImage()
        }
    }
    
    func loadImage() async {
        // Check cache first
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }
        
        isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                Self.cache.setObject(uiImage, forKey: url as NSURL)
                image = uiImage
            }
        } catch {
            // Handle error
        }
        
        isLoading = false
    }
}
```

### Preventing Memory Leaks

```swift
@Observable
class LocationTracker {
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: LocationDelegate?  // Weak reference
    
    func startTracking() {
        locationManager.publisher
            .sink { [weak self] location in  // Weak self in closures
                self?.processLocation(location)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
```

## View Update Optimization

### Expensive Computation Caching

```swift
struct RuckAnalyticsView: View {
    let sessions: [RuckSession]
    
    // ❌ Bad: Computed on every view update
    var statistics: RuckStatistics {
        calculateStatistics(from: sessions)  // Expensive operation
    }
    
    // ✅ Good: Cached computation
    @State private var statistics: RuckStatistics?
    
    var body: some View {
        Group {
            if let stats = statistics {
                StatisticsDisplay(stats: stats)
            } else {
                ProgressView()
            }
        }
        .task {
            statistics = await Task.detached {
                calculateStatistics(from: sessions)
            }.value
        }
    }
}
```

### EquatableView for Complex Views

```swift
struct ComplexChartView: View, Equatable {
    let dataPoints: [DataPoint]
    let configuration: ChartConfiguration
    
    // Custom equality check
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.dataPoints.count == rhs.dataPoints.count &&
        lhs.configuration.id == rhs.configuration.id
    }
    
    var body: some View {
        // Expensive chart rendering
        Canvas { context, size in
            // Complex drawing code
        }
    }
}

// Usage
ComplexChartView(dataPoints: data, configuration: config)
    .equatable()  // Only redraws when equality check fails
```

## Animation Performance

### Optimizing Animations

```swift
struct AnimatedRuckCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            // ❌ Bad: Animating expensive properties
            RoundedRectangle(cornerRadius: isExpanded ? 50 : 10)
                .shadow(radius: isExpanded ? 20 : 5)  // Shadow is expensive
                .animation(.default, value: isExpanded)
            
            // ✅ Good: Animate transforms instead
            RoundedRectangle(cornerRadius: 10)
                .scaleEffect(isExpanded ? 1.1 : 1.0)
                .animation(.default, value: isExpanded)
        }
    }
}
```

### Transaction Control

```swift
struct ControlledAnimationView: View {
    @State private var items: [Item] = []
    
    func addMultipleItems() {
        // Disable animation for batch updates
        withTransaction(Transaction(animation: nil)) {
            items.append(contentsOf: newItems)
        }
    }
    
    func animatedUpdate() {
        // Explicit animation control
        withAnimation(.spring(response: 0.3)) {
            items.shuffle()
        }
    }
}
```

## Instruments and Profiling

### Key Instruments for SwiftUI

1. **View Body Counter**: Track view update frequency
2. **Time Profiler**: Identify performance bottlenecks
3. **Memory Graph**: Find retain cycles and leaks
4. **Core Animation**: Monitor frame rates

### Performance Monitoring Code

```swift
// Development-only performance tracking
#if DEBUG
struct PerformanceView<Content: View>: View {
    let name: String
    let content: Content
    @State private var renderCount = 0
    
    init(name: String, @ViewBuilder content: () -> Content) {
        self.name = name
        self.content = content()
    }
    
    var body: some View {
        let _ = print("[\(name)] Render #\(renderCount)")
        let _ = { renderCount += 1 }()
        
        content
    }
}
#endif
```

## Background Task Management

### Efficient Background Updates

```swift
@Observable
class RuckDataSync {
    private var backgroundTask: Task<Void, Never>?
    
    func startBackgroundSync() {
        backgroundTask = Task.detached(priority: .background) {
            while !Task.isCancelled {
                await self.syncData()
                try? await Task.sleep(for: .seconds(300))  // 5 minutes
            }
        }
    }
    
    func stopBackgroundSync() {
        backgroundTask?.cancel()
    }
    
    @MainActor
    private func syncData() async {
        // Perform sync and update UI on main thread
    }
}
```

## List and Collection Performance

### Optimizing Large Lists

```swift
struct OptimizedRuckList: View {
    let rucks: [RuckSession]
    @State private var visibleRange = 0..<50
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                // Only render visible items + buffer
                ForEach(visibleRange, id: \.self) { index in
                    if index < rucks.count {
                        RuckRow(ruck: rucks[index])
                            .id(index)
                            .onAppear {
                                updateVisibleRange(around: index)
                            }
                    }
                }
            }
        }
    }
    
    private func updateVisibleRange(around index: Int) {
        let buffer = 25
        let start = max(0, index - buffer)
        let end = min(rucks.count, index + buffer)
        visibleRange = start..<end
    }
}
```

### Diffable Data Sources

```swift
struct DiffableList: View {
    @State private var items: [Item] = []
    
    var body: some View {
        List {
            ForEach(items) { item in
                ItemRow(item: item)
            }
        }
        .animation(.default, value: items)  // Smooth updates
    }
    
    func updateItems(_ newItems: [Item]) {
        // SwiftUI automatically diffs and animates changes
        items = newItems
    }
}
```

## SwiftUI Previews Performance

### Optimizing Preview Performance

```swift
// Use preview-specific data
struct RuckMapView_Previews: PreviewProvider {
    static var previews: some View {
        RuckMapView()
            .environment(\.mockedData, true)  // Use mocked data
            .previewDevice("iPhone 15 Pro")
            .task {
                // Disable animations in previews
                UIView.setAnimationsEnabled(false)
            }
    }
}

// Conditional compilation for preview data
extension RuckSession {
    static var previewData: [RuckSession] {
        #if DEBUG
        // Lightweight preview data
        return (0..<5).map { i in
            RuckSession(
                id: UUID(),
                distance: Double(i) * 2.5,
                duration: TimeInterval(i * 1800)
            )
        }
        #else
        return []
        #endif
    }
}
```

## Performance Best Practices Checklist

### View Updates
- [ ] Use stable IDs in ForEach
- [ ] Minimize @State changes
- [ ] Cache expensive computations
- [ ] Use EquatableView for complex views
- [ ] Avoid inline closures that capture state

### Memory Management
- [ ] Use weak references in closures
- [ ] Implement proper image caching
- [ ] Clean up observers in onDisappear
- [ ] Use @StateObject only for view-owned objects
- [ ] Profile with Instruments regularly

### Rendering
- [ ] Use lazy containers for large lists
- [ ] Implement view recycling patterns
- [ ] Optimize animation properties
- [ ] Minimize shadow and blur effects
- [ ] Use drawingGroup() for complex graphics

### Data Flow
- [ ] Keep models focused and small
- [ ] Use @Observable for granular updates
- [ ] Batch state updates when possible
- [ ] Avoid unnecessary bindings
- [ ] Use computed properties sparingly

## Measuring Performance

### Custom Performance Metrics

```swift
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var metrics: [String: TimeInterval] = [:]
    
    func measure<T>(_ label: String, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let end = CFAbsoluteTimeGetCurrent()
            metrics[label] = end - start
        }
        return try block()
    }
    
    func measureAsync<T>(_ label: String, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let end = CFAbsoluteTimeGetCurrent()
            Task { @MainActor in
                metrics[label] = end - start
            }
        }
        return try await block()
    }
}
```

## Conclusion

SwiftUI performance optimization requires understanding view identity, state management, and rendering behavior. Key strategies:

1. **Minimize view updates** through stable identity and efficient state management
2. **Lazy load content** to reduce memory usage
3. **Cache expensive operations** to avoid redundant computation
4. **Profile regularly** with Instruments
5. **Test on real devices** with realistic data sets

Remember: premature optimization is the root of all evil. Profile first, optimize what matters, and always measure the impact of your changes.