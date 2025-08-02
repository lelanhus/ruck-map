# Swift Testing Research

This directory contains comprehensive research on Swift Testing, Apple's modern testing framework designed specifically for Swift.

## 📚 Documentation Structure

1. **[comprehensive-research.md](./comprehensive-research.md)**
   - Complete research report on Swift Testing
   - Framework philosophy and design
   - Migration strategies from XCTest
   - Advanced features and patterns

2. **[quick-reference.md](./quick-reference.md)**
   - Concise syntax reference
   - Common testing patterns
   - Assertion examples
   - Migration cookbook

## 🔑 Key Features

### Core Improvements over XCTest
- **Modern Swift syntax** with macros (`@Test`, `#expect`)
- **Parallel execution by default** including on devices
- **Simplified assertions** - just 2 macros replace 40+ XCTAssert variants
- **Parameterized tests** with native support
- **Better error messages** with expression diagrams

### Test Organization
```swift
@Suite("Ruck Session Tests")
struct RuckSessionTests {
    @Test func creation() {
        let session = RuckSession(weight: 35)
        #expect(session.weight == 35)
    }
    
    @Test(arguments: [20, 35, 45])
    func variousWeights(weight: Double) {
        let session = RuckSession(weight: weight)
        #expect(session.weight > 0)
    }
}
```

### Assertions
```swift
// Non-fatal expectation
#expect(distance > 0)
#expect(calories == 350, accuracy: 10)

// Fatal requirement
let data = try #require(loadData())
```

## 🚀 Migration Strategy

### Gradual Adoption
1. **Both frameworks coexist** - no need to migrate all at once
2. **Start with new tests** - write them in Swift Testing
3. **Migrate by feature** - convert related test groups together
4. **Keep UI tests in XCTest** - Swift Testing doesn't support UI automation yet

### Quick Migration Example
```swift
// Before (XCTest)
func testSessionCreation() {
    let session = RuckSession(weight: 35)
    XCTAssertEqual(session.weight, 35)
    XCTAssertNil(session.endDate)
}

// After (Swift Testing)
@Test func sessionCreation() {
    let session = RuckSession(weight: 35)
    #expect(session.weight == 35)
    #expect(session.endDate == nil)
}
```

## ⚠️ Current Limitations

- **No UI testing support** - Use XCTest for UI automation
- **No performance testing** - XCTest's `measure` has no equivalent
- **Limited mocking** - No built-in mocking framework
- **Beta status** - Some APIs may change

## 💡 RuckMap Testing Patterns

### Async Testing
```swift
@Test func locationTracking() async throws {
    let service = LocationService()
    await service.startTracking()
    
    let location = try await service.waitForNextLocation()
    #expect(location.horizontalAccuracy < 20)
}
```

### SwiftData Testing
```swift
@Suite struct DatabaseTests {
    let container: ModelContainer
    
    init() async throws {
        container = try ModelContainer(
            for: [RuckSession.self],
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
    
    @Test func persistence() async throws {
        // Test with in-memory container
    }
}
```

### Known Issues Support
```swift
@Test func featureWithBug() {
    withKnownIssue("Tracking issue #123") {
        // Test that's expected to fail
        #expect(buggyFeature() == expected)
    }
}
```

## 📖 Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/testing)
- [WWDC24: Meet Swift Testing](https://developer.apple.com/videos/play/wwdc2024/10179/)
- [Migration Guide](https://developer.apple.com/documentation/testing/migratingfromxctest)
- [Swift Forums - Testing](https://forums.swift.org/c/development/testing)