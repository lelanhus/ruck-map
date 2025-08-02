---
description: Run comprehensive tests using swift-testing-expert for modern Swift Testing
allowed-tools: Task, Bash, Read, Grep
argument-hint: "[component|all]"
---

# /ruck-test

Run tests for RuckMap components using the swift-testing-expert for modern Swift Testing framework.

## Usage

```
/ruck-test [component]
```

## Examples

```
/ruck-test all          # Run entire test suite
/ruck-test algorithm    # Test calorie algorithm accuracy
/ruck-test gps         # Test GPS tracking and battery usage
/ruck-test ui          # Run UI tests and check performance
/ruck-test integration # Test system integration points
```

## Test Implementation

This command leverages **swift-testing-expert** to:
- Write tests using `@Test` and `#expect` macros
- Create parameterized tests for multiple scenarios
- Implement async tests for concurrent code
- Generate comprehensive test reports
- Ensure iOS 18+ Swift Testing best practices

## Test Categories

### Algorithm Tests (@Test with parameters)
```swift
@Test("Calorie calculation accuracy", 
      arguments: [
        (weight: 35, speed: 3.5, grade: 0, expected: 450, tolerance: 30),
        (weight: 35, speed: 3.5, grade: 5, expected: 650, tolerance: 40)
      ])
func testCalorieCalculation(weight: Double, speed: Double, grade: Double, expected: Double, tolerance: Double) async throws {
    // Test implementation
}
```

### GPS Tests (Async testing)
- Battery usage monitoring (<10% per hour)
- Distance accuracy validation (<2% error)
- Background operation verification
- Auto-pause functionality
- GPS compression efficiency

### UI Tests (MainActor testing)
- 60fps scrolling performance
- Launch time <2 seconds
- Memory usage <100MB active
- Haptic feedback timing
- Accessibility compliance

### Integration Tests (Tagged organization)
```swift
@Test(.tags(.healthKit))
func testHealthKitIntegration() async throws { }

@Test(.tags(.cloudKit))
func testCloudKitSync() async throws { }
```

## Test Execution Process

1. **Pre-Test Analysis** (swift-testing-expert):
   - Reviews existing test coverage
   - Identifies missing test scenarios
   - Suggests parameterized test cases

2. **Test Generation**:
   - Creates modern Swift Testing code
   - Implements proper async/await patterns
   - Adds comprehensive assertions
   - Includes performance measurements

3. **Execution**:
   ```bash
   !swift test --enable-code-coverage
   !xcrun llvm-cov report
   ```

4. **Post-Test Report**:
   - Coverage analysis
   - Performance metrics
   - Failed test diagnostics
   - Improvement suggestions

## Output Format

```
RuckMap Test Results
===================
Powered by Swift Testing Framework

📊 Test Summary:
- Total Tests: X
- Passed: ✅ X 
- Failed: ❌ X
- Skipped: ⏭️ X
- Coverage: X%

🔋 Performance Metrics:
- Battery Usage: X%/hour (Target: <10%)
- Memory Peak: XMB (Target: <100MB)
- Launch Time: Xs (Target: <2s)
- FPS Average: X (Target: 60)

❌ Failed Tests:
TestName.testMethod:42
  #expect(result == expected) // 450 != 475
  
⚠️ Coverage Gaps:
- LocationTracker.swift: 67% (missing: handleGPSError)
- CalorieCalculator.swift: 82% (missing: edge cases)

🎯 Swift Testing Improvements:
- Convert XCTest to @Test: 12 files
- Add parameterized tests: 5 opportunities
- Missing async tests: 3 methods

✅ Quality Gate: PASSED
Ready for: Next Session
```

## Modern Testing Features

### Parameterized Tests
- Test multiple scenarios efficiently
- Data-driven test cases
- Reduced code duplication

### Trait-Based Organization
```swift
@Suite("Calorie Algorithm Tests")
@Test(.timeLimit(.minutes(2)))
@Test(.tags(.critical, .algorithm))
```

### Async Testing
- Proper concurrency testing
- Actor isolation verification
- MainActor UI testing

### Custom Assertions
```swift
#expect(calories.isApproximately(450, tolerance: 30))
#require(session != nil, "Session must exist")
```

## Related Commands

- `/ruck-session` - Implement features with tests
- `/ruck-build test` - Build for testing
- `/ruck-performance` - Deep performance analysis
- `/ruck-status` - Check test coverage trends

This command ensures modern, maintainable tests using Swift Testing throughout development.