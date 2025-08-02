# SwiftUI Testing Strategies

## Overview

Testing SwiftUI applications requires a multi-faceted approach combining unit tests, UI tests, snapshot tests, and preview-driven development. This guide covers modern testing strategies for iOS 18+ applications.

## Unit Testing with Swift Testing Framework

### Basic Test Structure

```swift
import Testing
import SwiftUI
@testable import RuckTracker

@Suite("Ruck Session Tests")
struct RuckSessionTests {
    
    @Test("Calculate pace correctly")
    func calculatePace() {
        let session = RuckSession(
            distance: 3.0,  // miles
            duration: 3600  // 1 hour
        )
        
        #expect(session.pace == 3.0)
        #expect(session.formattedPace == "3.0 mph")
    }
    
    @Test("Handle zero duration")
    func zeroD
    
    @Test("Calculate calories burned", arguments: [
        (weight: 45.0, distance: 3.0, expectedCalories: 450),
        (weight: 35.0, distance: 5.0, expectedCalories: 583),
        (weight: 0.0, distance: 3.0, expectedCalories: 0)
    ])
    func calorieCalculation(weight: Double, distance: Double, expectedCalories: Int) {
        let session = RuckSession(
            distance: distance,
            weight: weight
        )
        
        #expect(session.caloriesBurned == expectedCalories)
    }
}
```

### Testing @Observable Classes

```swift
@Suite("View Model Tests")
struct ViewModelTests {
    
    @Test("Location tracking starts and stops correctly")
    func testLocationTracking() async {
        let viewModel = RuckViewModel()
        let mockLocationManager = MockLocationManager()
        viewModel.locationManager = mockLocationManager
        
        // Start tracking
        await viewModel.startRuck()
        
        #expect(viewModel.isTracking == true)
        #expect(mockLocationManager.isUpdatingLocation == true)
        
        // Simulate location updates
        await mockLocationManager.sendLocation(
            CLLocation(latitude: 37.7749, longitude: -122.4194)
        )
        
        #expect(viewModel.currentLocation != nil)
        
        // Stop tracking
        await viewModel.stopRuck()
        
        #expect(viewModel.isTracking == false)
        #expect(mockLocationManager.isUpdatingLocation == false)
    }
    
    @Test("State changes trigger UI updates")
    func testStateUpdates() async {
        let viewModel = RuckViewModel()
        var updateCount = 0
        
        // Observe changes
        withObservationTracking {
            _ = viewModel.distance
        } onChange: {
            updateCount += 1
        }
        
        // Change state
        viewModel.distance = 5.0
        
        #expect(updateCount == 1)
        #expect(viewModel.distance == 5.0)
    }
}
```

### Testing Business Logic

```swift
@Suite("Business Logic Tests")
struct BusinessLogicTests {
    
    @Test("Route optimization")
    func testRouteOptimization() async {
        let optimizer = RouteOptimizer()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7849, longitude: -122.4094),
            Waypoint(latitude: 37.7949, longitude: -122.3994)
        ]
        
        let optimized = await optimizer.optimize(waypoints)
        
        #expect(optimized.count == waypoints.count)
        #expect(optimized.totalDistance < waypoints.directDistance)
    }
    
    @Test("Data persistence")
    func testDataPersistence() async throws {
        let store = DataStore(inMemory: true)
        let session = RuckSession.sample
        
        // Save
        try await store.save(session)
        
        // Retrieve
        let retrieved = try await store.fetch(RuckSession.self, id: session.id)
        
        #expect(retrieved?.id == session.id)
        #expect(retrieved?.distance == session.distance)
    }
}
```

## UI Testing

### XCTest UI Testing

```swift
import XCTest

final class RuckTrackerUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func testStartRuckFlow() throws {
        // Navigate to start ruck
        app.buttons["Start Ruck"].tap()
        
        // Verify setup screen
        XCTAssertTrue(app.navigationBars["New Ruck"].exists)
        
        // Set weight
        let weightSlider = app.sliders["Weight Slider"]
        weightSlider.adjust(toNormalizedSliderPosition: 0.5)
        
        // Select route
        app.buttons["Select Route"].tap()
        app.cells["Fort Bragg Loop"].tap()
        
        // Start ruck
        app.buttons["Begin Ruck"].tap()
        
        // Verify active ruck screen
        XCTAssertTrue(app.staticTexts["Active Ruck"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)
    }
    
    func testTabNavigation() throws {
        // Test each tab
        let tabBar = app.tabBars.firstMatch
        
        tabBar.buttons["Routes"].tap()
        XCTAssertTrue(app.navigationBars["Routes"].exists)
        
        tabBar.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].exists)
        
        tabBar.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].exists)
    }
}
```

### Accessibility Testing

```swift
final class AccessibilityUITests: XCTestCase {
    
    func testVoiceOverNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIAccessibilityVoiceOverEnabled", "1"]
        app.launch()
        
        // Test accessibility labels
        let startButton = app.buttons["Start Ruck"]
        XCTAssertEqual(startButton.label, "Start Ruck")
        XCTAssertEqual(startButton.value as? String, "Begin a new ruck march session")
        
        // Test accessibility actions
        let ruckCell = app.cells["Ruck Session, 3.2 miles, 45 pounds, 52 minutes"]
        XCTAssertTrue(ruckCell.exists)
        
        // Verify custom actions
        let actions = ruckCell.accessibilityCustomActions
        XCTAssertTrue(actions.contains("Add to favorites"))
        XCTAssertTrue(actions.contains("Share"))
    }
    
    func testDynamicType() throws {
        let app = XCUIApplication()
        
        // Test different text sizes
        let textSizes = [
            "UICTContentSizeCategoryXS",
            "UICTContentSizeCategoryXXXL",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        
        for size in textSizes {
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", size]
            app.launch()
            
            // Verify text is visible and not truncated
            let titleLabel = app.staticTexts["Ruck Tracker"]
            XCTAssertTrue(titleLabel.isHittable)
            
            // Take screenshot for manual verification
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "DynamicType-\(size)"
            attachment.lifetime = .keepAlways
            add(attachment)
            
            app.terminate()
        }
    }
}
```

## Preview Testing

### Preview-Driven Development

```swift
#Preview("Ruck Card - All States") {
    VStack(spacing: 20) {
        // Active state
        RuckCard(session: .active)
            .previewDisplayName("Active")
        
        // Completed state
        RuckCard(session: .completed)
            .previewDisplayName("Completed")
        
        // Paused state
        RuckCard(session: .paused)
            .previewDisplayName("Paused")
    }
    .padding()
    .previewLayout(.sizeThatFits)
}

#Preview("Dynamic Type Variations") {
    RuckDetailView(session: .sample)
        .previewDisplayName("Standard")
    
    RuckDetailView(session: .sample)
        .environment(\.sizeCategory, .extraSmall)
        .previewDisplayName("Extra Small")
    
    RuckDetailView(session: .sample)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility XXXL")
}

#Preview("Color Schemes") {
    HStack {
        RuckCard(session: .sample)
            .preferredColorScheme(.light)
            .previewDisplayName("Light")
        
        RuckCard(session: .sample)
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")
    }
}
```

### Interactive Preview Testing

```swift
#Preview("Interactive States") {
    struct InteractiveContainer: View {
        @State private var isTracking = false
        @State private var weight: Double = 35
        @State private var distance: Double = 0
        
        var body: some View {
            VStack {
                ActiveRuckView(
                    isTracking: $isTracking,
                    weight: weight,
                    distance: distance
                )
                
                // Test controls
                GroupBox("Test Controls") {
                    Toggle("Is Tracking", isOn: $isTracking)
                    
                    Slider(value: $weight, in: 0...100) {
                        Text("Weight: \(weight, specifier: "%.0f") lbs")
                    }
                    
                    Slider(value: $distance, in: 0...10) {
                        Text("Distance: \(distance, specifier: "%.1f") mi")
                    }
                }
                .padding()
            }
        }
    }
    
    return InteractiveContainer()
}
```

## Snapshot Testing

### Using SnapshotTesting Library

```swift
import SnapshotTesting
import XCTest
@testable import RuckTracker

final class SnapshotTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Record new snapshots when needed
        // isRecording = true
    }
    
    func testRuckCardSnapshots() {
        let view = RuckCard(session: .sample)
            .frame(width: 375, height: 120)
        
        // Light mode
        assertSnapshot(
            matching: view,
            as: .image(traits: .init(userInterfaceStyle: .light)),
            named: "light"
        )
        
        // Dark mode
        assertSnapshot(
            matching: view,
            as: .image(traits: .init(userInterfaceStyle: .dark)),
            named: "dark"
        )
        
        // Different sizes
        assertSnapshot(
            matching: view,
            as: .image(size: CGSize(width: 320, height: 120)),
            named: "compact"
        )
    }
    
    func testDynamicTypeSnapshots() {
        let contentSizeCategories: [ContentSizeCategory] = [
            .extraSmall,
            .medium,
            .extraExtraExtraLarge,
            .accessibilityExtraExtraExtraLarge
        ]
        
        for category in contentSizeCategories {
            let view = RuckDetailView(session: .sample)
                .environment(\.sizeCategory, category)
            
            assertSnapshot(
                matching: view,
                as: .image(traits: .init(userInterfaceStyle: .light)),
                named: "sizeCategory-\(category)"
            )
        }
    }
}
```

### Visual Regression Testing

```swift
final class VisualRegressionTests: XCTestCase {
    
    func testComplexLayoutRegression() {
        let viewModel = RuckViewModel.mock
        let view = RuckMapView(viewModel: viewModel)
            .frame(width: 390, height: 844) // iPhone 14 Pro
        
        // Test different states
        let states: [(String, () -> Void)] = [
            ("initial", {}),
            ("tracking", { viewModel.startTracking() }),
            ("paused", { viewModel.pauseTracking() }),
            ("completed", { viewModel.completeRuck() })
        ]
        
        for (name, action) in states {
            action()
            
            assertSnapshot(
                matching: view,
                as: .image(precision: 0.95), // Allow 5% difference
                named: name
            )
        }
    }
}
```

## Integration Testing

### Testing View and Model Integration

```swift
@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("Complete ruck flow")
    func testCompleteRuckFlow() async throws {
        // Setup
        let dataStore = DataStore(inMemory: true)
        let viewModel = RuckViewModel(dataStore: dataStore)
        
        // Start ruck
        await viewModel.startRuck(weight: 45)
        #expect(viewModel.isActive == true)
        
        // Simulate location updates
        for i in 0..<10 {
            let location = CLLocation(
                latitude: 37.7749 + Double(i) * 0.001,
                longitude: -122.4194
            )
            await viewModel.updateLocation(location)
        }
        
        #expect(viewModel.distance > 0)
        
        // Complete ruck
        await viewModel.completeRuck()
        
        // Verify saved
        let sessions = try await dataStore.fetchAll(RuckSession.self)
        #expect(sessions.count == 1)
        #expect(sessions.first?.distance == viewModel.distance)
    }
}
```

### Testing Navigation Flow

```swift
@Test("Navigation state persistence")
func testNavigationPersistence() async {
    let navigation = NavigationModel()
    
    // Navigate through app
    navigation.navigateToRuck(RuckSession.sample)
    navigation.navigateToRoute(Route.sample)
    
    // Encode state
    let encoded = navigation.encodeState()
    #expect(encoded != nil)
    
    // Create new navigation with decoded state
    let newNavigation = NavigationModel()
    newNavigation.restoreState(from: encoded!)
    
    #expect(newNavigation.path.count == 2)
}
```

## Performance Testing

### Measure Performance

```swift
final class PerformanceTests: XCTestCase {
    
    func testLargeListPerformance() {
        let sessions = (0..<1000).map { _ in RuckSession.random }
        
        measure {
            let view = RuckListView(sessions: sessions)
            let controller = UIHostingController(rootView: view)
            
            // Force render
            _ = controller.view
            controller.view.layoutIfNeeded()
        }
    }
    
    func testAnimationPerformance() {
        let view = AnimatedMapView()
        let controller = UIHostingController(rootView: view)
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            // Trigger animations
            view.simulateRouteAnimation()
            
            // Wait for completion
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
        }
    }
}
```

## Test Utilities and Helpers

### Mock Data

```swift
extension RuckSession {
    static let sample = RuckSession(
        id: UUID(),
        date: Date(),
        distance: 3.2,
        duration: 3150,
        weight: 45,
        calories: 425
    )
    
    static let active = RuckSession(
        id: UUID(),
        date: Date(),
        distance: 1.5,
        duration: 1200,
        weight: 35,
        isActive: true
    )
    
    static var random: RuckSession {
        RuckSession(
            id: UUID(),
            date: Date.random(in: Date.distantPast...Date()),
            distance: Double.random(in: 1...10),
            duration: TimeInterval.random(in: 1200...7200),
            weight: Double.random(in: 20...60)
        )
    }
}
```

### Test View Modifiers

```swift
extension View {
    func testable() -> some View {
        self
            .environment(\.isUITesting, true)
            .environment(\.animationsDisabled, true)
    }
    
    func snapshot(size: CGSize? = nil) -> some View {
        let frame = size ?? CGSize(width: 390, height: 844)
        return self
            .frame(width: frame.width, height: frame.height)
            .background(Color.white)
            .environment(\.colorScheme, .light)
    }
}
```

### Custom Assertions

```swift
extension XCTestCase {
    func assertAccessible<V: View>(_ view: V, file: StaticString = #file, line: UInt = #line) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        
        // Run accessibility audit
        do {
            try controller.view.accessibilityAudit(for: [.contrast, .label, .hint, .trait])
        } catch {
            XCTFail("Accessibility audit failed: \(error)", file: file, line: line)
        }
    }
}
```

## Testing Best Practices

### 1. Test Pyramid

```swift
// Unit Tests (70%) - Fast, isolated
@Test func calculateDistance() { /* ... */ }

// Integration Tests (20%) - Component interaction
@Test func dataFlowIntegration() async { /* ... */ }

// UI/E2E Tests (10%) - Full user flows
func testCompleteUserJourney() { /* ... */ }
```

### 2. Test Organization

```swift
// Group related tests
@Suite("Ruck Calculations")
struct RuckCalculationTests { /* ... */ }

@Suite("Navigation")
struct NavigationTests { /* ... */ }

@Suite("Data Persistence")
struct DataPersistenceTests { /* ... */ }
```

### 3. Continuous Integration

```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: |
          xcodebuild test \
            -scheme RuckTracker \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -resultBundlePath TestResults
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: TestResults.xcresult
```

## Debugging Tests

### Test Failure Diagnostics

```swift
@Test("Debug failing test")
func debugTest() {
    let result = complexCalculation()
    
    // Add context to failures
    #expect(result > 0, "Result was \(result), expected positive value")
    
    // Use XCTContext for additional info
    XCTContext.runActivity(named: "Verify calculation steps") { _ in
        #expect(step1Result == expectedStep1)
        #expect(step2Result == expectedStep2)
    }
}
```

## Conclusion

Effective SwiftUI testing requires:

1. **Unit tests** for business logic and view models
2. **UI tests** for user flows and interactions
3. **Snapshot tests** for visual regression
4. **Preview testing** for rapid development
5. **Integration tests** for component interaction

Key takeaways:
- Use Swift Testing framework for modern test syntax
- Leverage previews for development-time testing
- Implement snapshot tests for UI stability
- Test accessibility from the start
- Maintain a healthy test pyramid
- Automate testing in CI/CD pipeline