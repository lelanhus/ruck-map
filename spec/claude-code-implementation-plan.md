# RuckMap Implementation Plan for Claude Code

## Overview
This plan assumes all coding will be performed by Claude Code in focused sessions. The approach emphasizes clear task definition, comprehensive context, and iterative development.

## Implementation Strategy

### Session Structure
Each coding session should:
1. Start with a clear, specific goal
2. Include all necessary context files
3. End with working, tested code
4. Document any decisions or trade-offs

### Optimal Session Length
- **2-4 hour sessions** work best for Claude Code
- Break complex features into multiple sessions
- Each session should produce a complete, testable component

## Phase 1: Foundation (Sessions 1-5)

### Session 1: Project Setup & Core Models
**Goal**: Create Xcode project with SwiftData models
**Context Files**: 
- `spec/feature-list-v2.md`
- `spec/technical-implementation-guide.md`
**Deliverables**:
- Xcode project configured for iOS 18+
- SwiftData models for RuckSession, LocationPoint, TerrainSegment
- Basic project structure
- Git repository initialized

### Session 2: Location Tracking Engine
**Goal**: Implement core GPS tracking with background support
**Context Files**:
- `spec/mvp-user-stories.md` (Story 1.1-1.3)
- `spec/technical-implementation-guide.md` (Section 1)
**Deliverables**:
- LocationTrackingManager class
- Background location updates
- Distance and pace calculations
- Auto-pause functionality

### Session 3: GPS Optimization & Battery Management
**Goal**: Optimize GPS for <10% battery usage
**Context Files**:
- Previous LocationTrackingManager
- `spec/technical-implementation-guide.md` (Battery Optimization)
**Deliverables**:
- Adaptive sampling implementation
- Battery monitoring
- GPS accuracy indicators
- State restoration

### Session 4: Elevation & Barometer Integration
**Goal**: Add elevation tracking with sensor fusion
**Context Files**:
- Current LocationTrackingManager
- `spec/mvp-user-stories.md` (elevation requirements)
**Deliverables**:
- CMAltimeter integration
- Barometer/GPS fusion
- Grade calculations
- Elevation gain/loss tracking

### Session 5: Data Persistence & Compression
**Goal**: Implement SwiftData persistence with GPS compression
**Context Files**:
- All models
- `spec/technical-implementation-guide.md` (Section 4)
**Deliverables**:
- Session saving/loading
- GPS track compression (Douglas-Peucker)
- Data migration strategy
- Export functionality (GPX/CSV)

## Phase 2: Calorie Algorithm (Sessions 6-8)

### Session 6: LCDA Algorithm Implementation
**Goal**: Implement military-grade calorie calculation
**Context Files**:
- `spec/rucking-calorie-algorithm-spec.md`
- `spec/technical-implementation-guide.md` (Section 3)
**Deliverables**:
- CalorieCalculator with Pandolf equation
- Environmental factors (temp, altitude, wind)
- Unit tests with known values
- Real-time calculation

### Session 7: Terrain Detection System
**Goal**: Implement terrain detection using MapKit + motion
**Context Files**:
- `spec/mvp-user-stories.md` (Story 2.2)
- Current CalorieCalculator
**Deliverables**:
- TerrainDetector class
- MapKit integration for hints
- Motion-based terrain analysis
- Manual override UI

### Session 8: Weather Integration
**Goal**: Integrate WeatherKit for conditions
**Context Files**:
- Current CalorieCalculator
- `spec/feature-list-v2.md` (weather requirements)
**Deliverables**:
- WeatherKit integration
- Weather factor calculations
- Automatic condition logging
- Weather UI display

## Phase 3: Core UI (Sessions 9-13)

### Session 9: Main App Structure
**Goal**: Create tab-based navigation with main views
**Context Files**:
- `spec/mvp-user-stories.md` (UI requirements)
- Current model layer
**Deliverables**:
- Tab bar structure
- Navigation architecture
- View models for each tab
- Basic styling

### Session 10: Active Tracking UI
**Goal**: Build the main tracking interface
**Context Files**:
- `spec/technical-implementation-guide.md` (Section 5)
- Current LocationTrackingManager
**Deliverables**:
- Real-time metrics display
- Start/stop/pause controls
- Load weight adjustment
- Haptic feedback

### Session 11: Map Integration
**Goal**: Add MapKit with route display
**Context Files**:
- Current tracking UI
- `spec/mvp-user-stories.md` (map requirements)
**Deliverables**:
- MapKit view with route
- Current location indicator
- Terrain type overlay
- Zoom/pan controls

### Session 12: Session Summary & History
**Goal**: Create post-ruck summary and history views
**Context Files**:
- Current models and UI
- `spec/mvp-user-stories.md` (Story 1.4)
**Deliverables**:
- Session summary screen
- RPE input
- Notes (text/voice)
- History list view

### Session 13: Analytics Dashboard
**Goal**: Build analytics with Swift Charts
**Context Files**:
- `spec/mvp-user-stories.md` (Epic 5)
- Current data models
**Deliverables**:
- Weekly/monthly summaries
- Progress charts
- Personal records
- Streak tracking

## Phase 4: Platform Integration (Sessions 14-18)

### Session 14: HealthKit Integration
**Goal**: Full HealthKit read/write integration
**Context Files**:
- `spec/technical-implementation-guide.md` (Section 6)
- `spec/mvp-user-stories.md` (Epic 4)
**Deliverables**:
- Permission requests
- Workout saving
- Heart rate reading
- Body metrics sync

### Session 15: Watch App Foundation
**Goal**: Create standalone Watch app
**Context Files**:
- `spec/mvp-user-stories.md` (Epic 3)
- Current iPhone app structure
**Deliverables**:
- Watch app target
- Basic UI structure
- Standalone GPS tracking
- Data models

### Session 16: Watch UI & Features
**Goal**: Complete Watch app functionality
**Context Files**:
- Current Watch app
- `spec/mvp-user-stories.md` (Story 3.2-3.3)
**Deliverables**:
- Complications
- Real-time displays
- Haptic alerts
- Crown navigation

### Session 17: Watch-iPhone Sync
**Goal**: Implement WatchConnectivity
**Context Files**:
- Both app targets
- `spec/technical-implementation-guide.md` (sync patterns)
**Deliverables**:
- Message passing
- Background sync
- Conflict resolution
- Offline storage

### Session 18: CloudKit Integration
**Goal**: Add cloud sync between devices
**Context Files**:
- Current data models
- `spec/mvp-user-stories.md` (Story 4.1)
**Deliverables**:
- CloudKit configuration
- Sync manager
- Conflict handling
- Privacy controls

## Phase 5: Polish & Release (Sessions 19-25)

### Session 19: Performance Optimization
**Goal**: Optimize battery, memory, and performance
**Context Files**:
- Entire codebase
- `spec/implementation-checklist.md` (performance criteria)
**Deliverables**:
- Battery usage <10%/hour
- Memory leak fixes
- 60fps UI
- Launch time <2s

### Session 20: Accessibility
**Goal**: Full accessibility support
**Context Files**:
- All UI code
- `spec/mvp-user-stories.md` (accessibility requirements)
**Deliverables**:
- VoiceOver support
- Dynamic Type
- Haptic options
- One-handed mode

### Session 21: Error Handling & Edge Cases
**Goal**: Robust error handling throughout
**Context Files**:
- Entire codebase
- `spec/compliance-and-disclaimers.md`
**Deliverables**:
- GPS failure handling
- Network error recovery
- Data corruption prevention
- User-friendly error messages

### Session 22: Settings & Onboarding
**Goal**: Create settings and first-run experience
**Context Files**:
- Current app structure
- `spec/mvp-user-stories.md` (settings requirements)
**Deliverables**:
- Settings view hierarchy
- Onboarding flow
- Permission explanations
- Unit preferences

### Session 23: Testing Suite
**Goal**: Comprehensive test coverage
**Context Files**:
- Entire codebase
- `spec/mvp-user-stories.md` (definition of done)
**Deliverables**:
- Unit tests >80% coverage
- UI test critical paths
- Performance tests
- Integration tests

### Session 24: Beta Preparation
**Goal**: Prepare for TestFlight beta
**Context Files**:
- `spec/compliance-and-disclaimers.md`
- Current app state
**Deliverables**:
- App Store assets
- Beta test plan
- Feedback collection
- Crash reporting

### Session 25: App Store Submission
**Goal**: Final polish and submission
**Context Files**:
- Beta feedback
- `spec/compliance-and-disclaimers.md`
**Deliverables**:
- Bug fixes from beta
- App Store listing
- Privacy policy
- Support documentation

## Best Practices for Claude Code Sessions

### 1. Session Preparation
- Define one clear goal per session
- Include all relevant context files
- Specify acceptance criteria
- Mention any constraints or preferences

### 2. Effective Prompts
```
"Implement the LocationTrackingManager class from the technical implementation guide. 
Focus on battery efficiency (<10% per hour) and background reliability. 
Include unit tests for distance calculation and auto-pause logic.
Reference the mvp-user-stories.md for acceptance criteria."
```

### 3. Session Management
- Test each component before moving to next
- Document any technical decisions
- Create TODO comments for future sessions
- Commit working code frequently

### 4. Context Preservation
- Keep a running log of decisions
- Update specs if requirements change
- Document any workarounds or limitations
- Track performance metrics

### 5. Quality Checks
After each session verify:
- [ ] Code compiles without warnings
- [ ] Tests pass
- [ ] No memory leaks
- [ ] Battery usage acceptable
- [ ] UI performs at 60fps

## Timeline Estimate

With focused Claude Code sessions:
- **Phase 1**: 5 sessions (2-3 days)
- **Phase 2**: 3 sessions (1-2 days)
- **Phase 3**: 5 sessions (2-3 days)
- **Phase 4**: 5 sessions (2-3 days)
- **Phase 5**: 7 sessions (3-4 days)

**Total**: 25 sessions over 10-15 days of active development

This assumes:
- 2-3 sessions per day maximum
- Time between sessions for planning
- Buffer for iteration and fixes

## Success Metrics

Track these after each phase:
- Battery usage trend
- Memory footprint
- Code coverage
- Performance benchmarks
- Feature completeness

This plan optimizes for Claude Code's strengths: focused, well-defined tasks with clear context and deliverables.