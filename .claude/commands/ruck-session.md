---
description: Execute a RuckMap implementation session using specialized sub-agents
allowed-tools: Task, Bash, Read, Write, Edit, MultiEdit, Grep, Glob, TodoWrite
argument-hint: "[session-number|next]"
---

# /ruck-session

Execute a RuckMap implementation session from the planning documents using specialized sub-agents.

## Usage

```
/ruck-session [session-number]
```

## Examples

```
/ruck-session 1      # Start Session 1: Project Setup & Core Models
/ruck-session 6      # Start Session 6: LCDA Algorithm Implementation  
/ruck-session next   # Continue with the next uncompleted session
```

## What This Command Does

1. **Creates a new git branch** named `session/XX-feature-name`
2. **Loads the session details** from `spec/claude-code-implementation-plan.md`
3. **Identifies appropriate sub-agents** for the session tasks
4. **Delegates implementation** to specialized experts
5. **Coordinates testing** with swift-testing-expert
6. **Commits code incrementally** with descriptive messages
7. **Prepares for PR creation** at session end

## Sub-Agent Utilization

Each session leverages specific sub-agents:

### Data & Models (Sessions 1, 5)
- **swiftdata-expert**: Model design and persistence
- **swift6-concurrency-expert**: Actor isolation and async patterns

### Location & Sensors (Sessions 2-4)
- **core-location-expert**: GPS tracking implementation
- **mapkit-expert**: Map integration and visualization
- **performance-expert**: Battery optimization

### Algorithms (Sessions 6-8)
- **coreml-expert**: ML-based terrain detection
- **weatherkit-expert**: Weather integration

### UI Implementation (Sessions 9-13)
- **swiftui-implementation-expert**: View architecture
- **swiftcharts-expert**: Analytics visualization
- **accessibility-expert**: VoiceOver and Dynamic Type

### Platform Integration (Sessions 14-18)
- **healthkit-expert**: Health data integration
- **watchos-expert**: Watch app development
- **widgetkit-expert**: Widget implementation
- **activitykit-expert**: Live Activities

### Quality & Polish (Sessions 19-25)
- **performance-expert**: Optimization and profiling
- **swift-testing-expert**: Test coverage
- **accessibility-expert**: Full accessibility audit

## Session Structure

Each session will:
- Start with a clear goal and context
- Implement the specified component completely
- Include unit tests where applicable
- Verify performance requirements are met
- Document any technical decisions
- Create a git commit with the changes

## Available Sessions

### Phase 1: Foundation (1-5)
1. Project Setup & Core Models
2. Location Tracking Engine
3. GPS Optimization & Battery Management
4. Elevation & Barometer Integration
5. Data Persistence & Compression

### Phase 2: Calorie Algorithm (6-8)
6. LCDA Algorithm Implementation
7. Terrain Detection System
8. Weather Integration

### Phase 3: Core UI (9-13)
9. Main App Structure
10. Active Tracking UI
11. Map Integration
12. Session Summary & History
13. Analytics Dashboard

### Phase 4: Platform Integration (14-18)
14. HealthKit Integration
15. Watch App Foundation
16. Watch UI & Features
17. Watch-iPhone Sync
18. CloudKit Integration

### Phase 5: Polish & Release (19-25)
19. Performance Optimization
20. Accessibility
21. Error Handling & Edge Cases
22. Settings & Onboarding
23. Testing Suite
24. Beta Preparation
25. App Store Submission

## Success Criteria

After each session:
- [ ] Code compiles without warnings
- [ ] Tests pass (if applicable)
- [ ] Performance targets met
- [ ] No memory leaks
- [ ] Documentation updated
- [ ] Git commits created with conventional format
- [ ] Branch pushed to origin
- [ ] Ready for PR to develop branch

## Tips

- Complete sessions in order for best results
- Allow 2-4 hours per session
- Test thoroughly before moving to next session
- Review `spec/mvp-user-stories.md` for detailed requirements
- Check `spec/technical-implementation-guide.md` for code patterns

## Error Handling

If a session fails or is incomplete:
1. Review the error messages
2. Check if prerequisites are met
3. Verify all context files exist
4. Try running with more specific constraints

## Git Workflow

Each session follows this git flow:
```bash
# 1. Start: Create session branch
git checkout -b session/XX-feature-name

# 2. During: Incremental commits
git add .
git commit -m "feat: implement core functionality"
git commit -m "test: add unit tests"
git commit -m "fix: address performance issues"

# 3. End: Push and prepare PR
git push -u origin session/XX-feature-name
```

## Next Steps

After completing a session:
1. Review the implementation
2. Run the test suite
3. Check performance metrics
4. Push branch to origin
5. Create PR to develop branch
6. Proceed to the next session or take a break

## PR Template

After session completion, create PR with:
```markdown
## Session XX: [Feature Name]

### Completed:
- [ ] Implementation matches spec
- [ ] Tests pass with >80% coverage
- [ ] Performance targets met
- [ ] No memory leaks

### Metrics:
- Battery: X%/hour (target <10%)
- Coverage: X% (target >80%)
- Performance: Xfps (target 60)
```

This command streamlines the RuckMap development process by automating the setup and context for each implementation session while maintaining clean git history.