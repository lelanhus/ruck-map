# Swift Testing Quick Reference

## Basic Test Structure

```swift
import Testing
@testable import RuckMap

@Test func sessionCreation() async throws {
    // Arrange
    let weight = 35.0
    let startDate = Date()
    
    // Act
    let session = RuckSession(startDate: startDate, weight: weight)
    
    // Assert
    #expect(session.weight == weight)
    #expect(session.startDate == startDate)
    #expect(session.endDate == nil)
}
```

## Assertions

### #expect - Non-fatal assertions
```swift
@Test func distanceCalculation() {
    let distance = calculateDistance(from: pointA, to: pointB)
    #expect(distance > 0)
    #expect(distance == 5000, accuracy: 10)
}

// With custom messages
@Test func calorieCalculation() {
    let calories = calculateCalories(weight: 35, distance: 5000)
    #expect(calories > 300) { 
        "Calories should be significant for 5km ruck with 35lbs"
    }
}
```

### #require - Fatal assertions
```swift
@Test func routeParsing() async throws {
    let data = try #require(loadGPXData())
    let route = try #require(parseRoute(from: data))
    
    #expect(route.waypoints.count > 0)
}
```

## Parameterized Tests

```swift
@Test(arguments: [
    (weight: 20.0, distance: 3000.0, expectedCalories: 180.0),
    (weight: 35.0, distance: 5000.0, expectedCalories: 350.0),
    (weight: 45.0, distance: 10000.0, expectedCalories: 850.0)
])
func calorieAccuracy(weight: Double, distance: Double, expectedCalories: Double) {
    let calories = calculateCalories(weight: weight, distance: distance)
    #expect(calories == expectedCalories, accuracy: expectedCalories * 0.1)
}

// Matrix testing
@Test(arguments: 
    [20.0, 35.0, 45.0],  // weights
    [3000.0, 5000.0, 10000.0]  // distances
)
func allCombinations(weight: Double, distance: Double) {
    let calories = calculateCalories(weight: weight, distance: distance)
    #expect(calories > 0)
}
```

## Test Organization

### Test Suites
```swift
@Suite("Ruck Session Tests")
struct RuckSessionTests {
    let testUser = User(name: "Test", weight: 150, height: 70)
    
    @Test func creation() {
        // Test implementation
    }
    
    @Test func completion() async throws {
        // Test implementation
    }
}

@Suite("Location Services", .serialized)
struct LocationTests {
    // Tests run serially instead of parallel
}
```

### Tags and Traits
```swift
@Test(.tags(.slow, .integration))
func fullSyncTest() async throws {
    // Long-running integration test
}

@Test(.disabled("Waiting for API implementation"))
func futureFeature() {
    // Disabled test
}

@Test(.timeLimit(.minutes(2)))
func performanceTest() async {
    // Test with time limit
}

// Custom tags
extension Tag {
    @Tag static var slow: Self
    @Tag static var integration: Self
    @Tag static var unit: Self
}
```

## Async Testing

```swift
@Test func locationTracking() async throws {
    let service = LocationService()
    
    // Start tracking
    await service.startTracking()
    
    // Wait for location update
    let location = try await service.waitForNextLocation()
    
    #expect(location.horizontalAccuracy < 20)
}

// With timeout
@Test(.timeLimit(.seconds(5)))
func quickResponse() async throws {
    let result = try await networkService.fetchData()
    #expect(!result.isEmpty)
}
```

## Known Issues Support

```swift
@Test func featureWithBug() throws {
    try withKnownIssue {
        // This is expected to fail due to known bug
        let result = processData()
        #expect(result.isValid)
    } when: {
        // Only treat as known issue on iOS 17
        #available(iOS 17, *)
    }
}

@Test func intermittentFailure() {
    withKnownIssue("Server occasionally returns 503") {
        let response = try await api.fetchData()
        #expect(response.statusCode == 200)
    }
}
```

## Custom Expectations

```swift
// Custom validation
@Test func routeValidation() {
    let route = Route(name: "Test Route")
    #expect(route.isValid) { route in
        !route.name.isEmpty && 
        route.waypoints.count >= 2 &&
        route.distance > 0
    }
}

// Async expectations
@Test func eventualConsistency() async {
    await dataStore.save(item)
    
    await #expect { 
        await dataStore.contains(item)
    }
}
```

## Testing Errors

```swift
@Test func invalidInput() {
    #expect(throws: ValidationError.self) {
        try createSession(weight: -10)
    }
    
    #expect(throws: ValidationError.invalidWeight) {
        try createSession(weight: 500)
    }
}

// Async error testing
@Test func networkError() async {
    await #expect(throws: NetworkError.self) {
        try await fetchWithBadURL()
    }
}
```

## Setup and Teardown

```swift
@Suite struct DatabaseTests {
    var database: Database
    
    init() async throws {
        database = try await Database.inMemory()
    }
    
    deinit {
        database.close()
    }
    
    @Test func insertion() async throws {
        try await database.insert(testItem)
        let count = try await database.count()
        #expect(count == 1)
    }
}
```

## Migration from XCTest

### Before (XCTest)
```swift
class SessionTests: XCTestCase {
    func testCreation() {
        let session = RuckSession(weight: 35)
        XCTAssertEqual(session.weight, 35)
        XCTAssertNotNil(session.id)
        XCTAssertNil(session.endDate)
    }
}
```

### After (Swift Testing)
```swift
@Test func sessionCreation() {
    let session = RuckSession(weight: 35)
    #expect(session.weight == 35)
    #expect(session.id != nil)
    #expect(session.endDate == nil)
}
```

## Running Tests

```bash
# Run all tests
swift test

# Run specific suite
swift test --filter "RuckSessionTests"

# Run by tag
swift test --filter ".tags(.unit)"

# Skip slow tests
swift test --skip ".tags(.slow)"

# Parallel execution control
swift test --parallel-workers 4
```

## Best Practices

1. **Use descriptive test names** - They appear in test output
2. **Prefer #expect over #require** unless the test cannot continue
3. **Use parameterized tests** for multiple similar scenarios
4. **Tag appropriately** for test organization
5. **Set time limits** on potentially long-running tests
6. **Use .serialized** sparingly - parallel is default and faster
7. **Leverage known issues** for tracking regressions