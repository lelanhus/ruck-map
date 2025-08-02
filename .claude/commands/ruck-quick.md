# /ruck-quick

Quick actions for common RuckMap development tasks.

## Usage

```
/ruck-quick [action]
```

## Available Actions

### `/ruck-quick fix [issue]`
Quick fixes for common issues:
```
/ruck-quick fix battery      # Optimize GPS battery usage
/ruck-quick fix memory       # Fix memory leaks
/ruck-quick fix performance  # Improve UI performance
/ruck-quick fix crash        # Debug and fix crashes
```

### `/ruck-quick add [feature]`
Add small features or improvements:
```
/ruck-quick add haptic       # Add haptic feedback
/ruck-quick add animation    # Add UI animations
/ruck-quick add accessibility # Improve VoiceOver support
/ruck-quick add setting      # Add a new setting option
```

### `/ruck-quick refactor [component]`
Refactor existing code:
```
/ruck-quick refactor models   # Clean up data models
/ruck-quick refactor ui       # Improve view structure
/ruck-quick refactor tests    # Enhance test coverage
```

### `/ruck-quick docs [type]`
Generate documentation:
```
/ruck-quick docs api         # API documentation
/ruck-quick docs readme      # Update README
/ruck-quick docs help        # In-app help content
```

## Quick Fix Details

### Battery Optimization
- Implements adaptive GPS sampling
- Reduces location updates when stationary
- Optimizes background processing
- Target: <10% battery/hour

### Memory Fixes
- Identifies retain cycles
- Fixes SwiftData leaks
- Optimizes image handling
- Clears unused caches

### Performance Improvements
- Profiles slow code paths
- Optimizes SwiftUI updates
- Reduces unnecessary computations
- Ensures 60fps UI

### Crash Fixes
- Analyzes crash logs
- Adds safety checks
- Handles edge cases
- Improves error recovery

## Output Format

```
Quick Action: [Action Type]
========================

🎯 Objective: [What will be done]

📝 Changes Made:
- [Change 1]
- [Change 2]
- [Change 3]

✅ Results:
- [Improvement metric]
- [Performance gain]
- [Issue resolved]

📊 Before/After:
- Metric: X → Y
- Performance: X → Y

🔍 Next Steps:
- [Any follow-up needed]
- [Additional testing required]
```

## Use Cases

- **Hot fixes**: Quickly address critical issues
- **Polish**: Add small improvements between sessions
- **Optimization**: Fine-tune performance
- **Maintenance**: Keep code clean and documented

## Time Estimates

- Quick fixes: 15-30 minutes
- Small features: 30-60 minutes
- Refactoring: 1-2 hours
- Documentation: 30-45 minutes

## Best Practices

1. Use for small, focused tasks only
2. Run tests after each quick action
3. Commit changes immediately
4. Document what was changed
5. Don't use for major features

## Related Commands

- `/ruck-session` - Full implementation sessions
- `/ruck-test` - Run test suite
- `/ruck-status` - Check progress

This command enables rapid iterations and fixes without full session overhead.