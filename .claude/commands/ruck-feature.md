---
description: Develop a specific RuckMap feature using the appropriate expert sub-agent
allowed-tools: Task, Read, Write, Edit, MultiEdit, Grep, Glob, TodoWrite
argument-hint: "[feature-name]"
---

# /ruck-feature

Develop a specific RuckMap feature using specialized sub-agents based on the feature type.

## Usage

```
/ruck-feature [feature-name]
```

## Examples

```
/ruck-feature route-planning      # Implement route planning with mapkit-expert
/ruck-feature live-activity      # Create Live Activity with activitykit-expert
/ruck-feature unit-leaderboard   # Build unit features with swiftui-implementation-expert
/ruck-feature workout-sync       # Implement HealthKit sync with healthkit-expert
```

## Supported Features

### Navigation & Maps
- `route-planning` - Pre-planned routes with waypoints
- `route-sharing` - Share routes with other users
- `offline-maps` - Download maps for offline use
- `heat-maps` - Popular routes visualization

### Tracking & Sensors
- `auto-pause` - Smart pause detection
- `interval-training` - Timed interval support
- `cadence-tracking` - Steps per minute
- `heart-zones` - Heart rate zone training

### Social & Military
- `unit-leaderboard` - Unit/squad competitions
- `challenge-mode` - Personal/group challenges
- `achievement-system` - Badges and milestones
- `aar-reports` - After Action Reports

### Integration Features
- `workout-sync` - HealthKit integration
- `strava-export` - Export to Strava
- `live-activity` - Dynamic Island support
- `watch-companion` - Apple Watch features

### Analytics & Insights
- `performance-trends` - Long-term analytics
- `fatigue-prediction` - ML-based fatigue model
- `weather-planning` - Weather-based recommendations
- `calorie-insights` - Detailed burn analysis

## Feature Development Process

1. **Specification** (with feature-spec-writer):
   - Define user stories
   - Create acceptance criteria
   - Design data models
   - Plan UI/UX flow

2. **Implementation** (with appropriate expert):
   - Create feature branch
   - Implement core functionality
   - Add necessary UI components
   - Integrate with existing systems

3. **Testing** (with swift-testing-expert):
   - Unit tests for logic
   - UI tests for interactions
   - Integration tests
   - Performance validation

4. **Polish** (with accessibility-expert):
   - Accessibility compliance
   - Haptic feedback
   - Error handling
   - Edge cases

## Sub-Agent Mapping

The command automatically selects the right expert:

```
route-* features     → mapkit-expert
live-* features      → activitykit-expert
unit-* features      → swiftui-implementation-expert + swift-security-expert
workout-* features   → healthkit-expert
watch-* features     → watchos-expert
widget-* features    → widgetkit-expert
ml-* features        → coreml-expert
weather-* features   → weatherkit-expert
chart-* features     → swiftcharts-expert
```

## Output Structure

```
Feature: [Feature Name]
Expert: [Selected Sub-Agent]
Branch: feature/[feature-name]

📋 Implementation Plan:
1. [Step 1]
2. [Step 2]
3. [Step 3]

🎯 Acceptance Criteria:
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

💻 Implementation:
[Feature implementation begins...]
```

## Feature Flags

For gradual rollout:
```swift
@FeatureFlag("route_planning")
var isRoutePlanningEnabled = false
```

## Related Commands

- `/ruck-session` - For major implementation sessions
- `/ruck-test` - Test the new feature
- `/ruck-liquid-glass` - Ensure iOS 26 compatibility
- `/ruck-performance` - Profile feature performance

This command streamlines feature development by automatically engaging the right expertise for each feature type.