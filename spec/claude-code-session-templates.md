# Claude Code Session Templates

## Session Prompt Templates

### 1. Foundation Session Template
```
Create the [COMPONENT NAME] for RuckMap following these specifications:

Context Files:
- @spec/technical-implementation-guide.md (Section X)
- @spec/mvp-user-stories.md (Story X.X)
- @spec/feature-list-v2.md (Feature #X)

Requirements:
1. [Specific requirement 1]
2. [Specific requirement 2]
3. [Specific requirement 3]

Acceptance Criteria:
- [ ] [Measurable criterion 1]
- [ ] [Measurable criterion 2]
- [ ] [Measurable criterion 3]

Technical Constraints:
- iOS 18+ deployment target
- Swift 6 concurrency
- SwiftUI only (no UIKit)
- Must support background operation

Please implement with tests and verify it compiles.
```

### 2. Feature Implementation Template
```
Implement [FEATURE NAME] for RuckMap.

Current State:
- [What exists already]
- [Related components]

Goal:
[Clear description of what should work after this session]

Reference Implementation:
@spec/technical-implementation-guide.md (Section X shows the pattern)

Key Requirements:
- [Requirement 1 with specific metric]
- [Requirement 2 with specific metric]

Edge Cases to Handle:
- [Edge case 1]
- [Edge case 2]

Test by:
1. [How to verify it works]
2. [Performance metric to check]
```

### 3. Integration Session Template
```
Integrate [SYSTEM A] with [SYSTEM B] in RuckMap.

Existing Components:
- @path/to/SystemA.swift
- @path/to/SystemB.swift

Integration Goals:
1. [Data flow requirement]
2. [Sync requirement]
3. [Error handling requirement]

Reference the integration pattern in:
- @spec/mvp-user-stories.md (Story X.X)

Must maintain:
- Battery usage <10%/hour
- 60fps UI performance
- Offline functionality

Include integration tests.
```

### 4. UI Implementation Template
```
Build the [VIEW NAME] for RuckMap.

Design Requirements:
- @spec/mvp-user-stories.md (Story X.X for acceptance criteria)
- Large, glanceable numbers for metrics
- Support one-handed operation
- Full Dynamic Type support

Functionality:
1. [User action 1] -> [Result]
2. [User action 2] -> [Result]

Connect to:
- [ViewModel/Manager]
- [Data source]

Accessibility:
- VoiceOver labels for all controls
- Haptic feedback for actions
- Minimum tap targets 44pt

Test the UI manually and ensure 60fps scrolling.
```

### 5. Optimization Session Template
```
Optimize [COMPONENT] for [METRIC].

Current Performance:
- [Current metric value]

Target:
- [Target metric value]

Files to Optimize:
- @path/to/file1.swift
- @path/to/file2.swift

Optimization Strategies:
1. [Strategy 1]
2. [Strategy 2]

Maintain:
- All existing functionality
- Test coverage
- Code readability

Measure and document the improvement.
```

## Specific Session Prompts

### Session 1: Project Setup
```
Create a new RuckMap Xcode project with SwiftData models.

Requirements:
1. iOS 18+ deployment target
2. SwiftUI app lifecycle
3. Include SwiftData models from @spec/technical-implementation-guide.md Section 2
4. Configure for background location and HealthKit
5. Set up proper project structure as defined in @spec/implementation-checklist.md
6. Initialize git with proper .gitignore

Create these SwiftData models:
- RuckSession (with all properties from spec)
- LocationPoint
- TerrainSegment
- WeatherConditions

Include model relationships and basic validation.
```

### Session 6: LCDA Algorithm
```
Implement the military-grade calorie calculation algorithm for RuckMap.

Use the exact algorithm from:
- @spec/rucking-calorie-algorithm-spec.md
- @spec/technical-implementation-guide.md Section 3

Requirements:
1. Implement Pandolf equation with all factors
2. Add temperature adjustments (-5°C to 35°C range)
3. Include altitude adjustments (>1500m)
4. Support terrain factors (1.0-2.1 range)
5. Calculate confidence intervals
6. Real-time burn rate (cal/min)

Create comprehensive unit tests verifying:
- 35lb ruck, 3.5mph, flat: 450±30 cal/hr
- 35lb ruck, 3.5mph, 5% grade: 650±40 cal/hr
- Results within 10% of research data

Make it performant for real-time updates.
```

### Session 10: Active Tracking UI
```
Build the main active tracking UI for RuckMap.

Reference:
- @spec/mvp-user-stories.md Story 1.2
- @spec/technical-implementation-guide.md Section 5

Create a view that displays:
1. Large, glanceable metrics (distance, time, pace, calories)
2. Start/stop/pause controls with haptic feedback
3. Quick weight adjustment (± buttons)
4. GPS signal quality indicator
5. Swipe between metric screens

Connect to LocationTrackingManager and update in real-time.
Ensure 60fps performance and one-handed operation.
Include VoiceOver support for all elements.
```

### Session 15: Watch App Foundation
```
Create the Apple Watch companion app for RuckMap.

Requirements from @spec/mvp-user-stories.md Epic 3:
1. Standalone GPS tracking without iPhone
2. Display key metrics (time, distance, pace, HR, calories)
3. Start/stop/pause with haptic feedback
4. Store 48 hours of data locally
5. Heart rate integration
6. Complication showing last ruck stats

Set up:
- Watch app target
- Shared data models
- WatchConnectivity framework
- Background workout session
- HealthKit authorization

Focus on battery efficiency for 6+ hour sessions.
```

## Session Success Checklist

Before starting any session:
- [ ] Clear, single goal defined
- [ ] All context files referenced
- [ ] Acceptance criteria specified
- [ ] Performance targets stated

After completing any session:
- [ ] Code compiles without warnings
- [ ] Tests pass (if applicable)
- [ ] Performance metrics met
- [ ] No memory leaks
- [ ] Documentation updated
- [ ] Git commit created

## Tips for Effective Sessions

1. **Be Specific**: Instead of "implement GPS tracking", say "implement LocationTrackingManager with adaptive sampling for <10% battery usage"

2. **Include Context**: Always reference the relevant spec files and existing code

3. **Define Success**: Give clear acceptance criteria and performance targets

4. **Iterate**: Plan for follow-up sessions to refine and optimize

5. **Test Early**: Ask Claude Code to verify functionality during the session

These templates ensure consistent, high-quality implementation sessions with Claude Code.