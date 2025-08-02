# /ruck-status

Check the current implementation status of RuckMap and suggest next steps.

## Usage

```
/ruck-status
```

## What This Command Does

1. **Analyzes current codebase** to determine completed components
2. **Checks against implementation plan** to identify what's done
3. **Suggests the next session** to work on
4. **Reports on key metrics**:
   - Battery usage (target: <10%/hour)
   - Test coverage (target: >80%)
   - Performance benchmarks
   - Completion percentage

## Output Format

```
RuckMap Implementation Status
============================

✅ Completed Sessions (X/25):
- Session 1: Project Setup & Core Models
- Session 2: Location Tracking Engine
...

🚧 Current Phase: [Phase Name]
Progress: ████████░░ 40%

📊 Key Metrics:
- Battery Usage: [X]% per hour (Target: <10%)
- Test Coverage: [X]% (Target: >80%)
- Crash Rate: [X]% (Target: <0.1%)
- App Size: [X]MB (Target: <50MB)

🎯 Next Recommended Session:
Session [X]: [Session Name]
Goal: [Session Goal]
Estimated Time: [2-4 hours]

💡 Recommendations:
- [Any specific issues to address]
- [Performance improvements needed]
- [Technical debt to resolve]
```

## Integration Points

This command checks:
- Existence of key files and classes
- Test coverage reports
- Performance profiling data
- Git commit history
- TODO comments in code

## Use Cases

- **Daily standup**: Check progress at start of day
- **Session planning**: Decide what to work on next
- **Quality check**: Ensure metrics are on track
- **Progress reporting**: Share status with stakeholders

## Related Commands

- `/ruck-session [number]` - Start a specific implementation session
- `/ruck-test` - Run the full test suite
- `/ruck-profile` - Check performance metrics

This command helps maintain momentum and ensures the implementation stays on track.