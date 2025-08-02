# RuckMap Claude Code Commands

Custom slash commands for efficient RuckMap development with Claude Code.

## Available Commands

### 🚀 `/ruck-session [number]`
Execute a focused implementation session from the 25-session plan.

**Examples:**
- `/ruck-session 1` - Start project setup
- `/ruck-session 6` - Implement calorie algorithm
- `/ruck-session next` - Continue with next session

**What it does:**
- Loads session goals and context
- Includes all required spec files
- Implements complete component
- Runs tests and verifies quality

### 📊 `/ruck-status`
Check current implementation progress and get recommendations.

**What it shows:**
- Completed sessions (X/25)
- Current phase and progress
- Key metrics (battery, coverage, performance)
- Next recommended session
- Any issues to address

### ✅ `/ruck-test [component]`
Run tests and verify implementation quality.

**Options:**
- `/ruck-test all` - Full test suite
- `/ruck-test algorithm` - Calorie accuracy
- `/ruck-test gps` - Tracking & battery
- `/ruck-test ui` - Performance tests

**Validates:**
- Target metrics are met
- No regressions introduced
- Code coverage >80%
- Performance within limits

### ⚡ `/ruck-quick [action]`
Quick fixes and small improvements.

**Actions:**
- `/ruck-quick fix battery` - Optimize GPS usage
- `/ruck-quick fix memory` - Resolve leaks
- `/ruck-quick add haptic` - Add feedback
- `/ruck-quick refactor models` - Clean up code

**Use for:**
- Hot fixes (15-30 min)
- Small features (30-60 min)
- Code cleanup (1-2 hours)

## Implementation Plan Overview

The project is organized into **25 sessions** across **5 phases**:

1. **Foundation** (Sessions 1-5): Core tracking and models
2. **Algorithm** (Sessions 6-8): Calorie calculation
3. **UI** (Sessions 9-13): User interface
4. **Integration** (Sessions 14-18): Watch, HealthKit, Cloud
5. **Polish** (Sessions 19-25): Optimization and release

## Quick Start

```bash
# Start your first session
/ruck-session 1

# After implementation, check status
/ruck-status

# Run tests to verify
/ruck-test all

# Fix any issues
/ruck-quick fix [issue]
```

## Session Workflow

1. **Start**: Use `/ruck-session X` to begin
2. **Implement**: Claude Code builds the component
3. **Test**: Verify with `/ruck-test`
4. **Fix**: Use `/ruck-quick` for issues
5. **Check**: Run `/ruck-status` for next steps

## Key Targets

- 🔋 Battery: <10% per hour
- 📱 Performance: 60fps UI
- 🧪 Tests: >80% coverage
- 💾 Memory: <100MB active
- ⏱️ Launch: <2 seconds
- 📊 Accuracy: <10% calorie error

## Tips for Success

1. **Complete sessions in order** - They build on each other
2. **Test after each session** - Catch issues early
3. **One session at a time** - 2-4 hours each
4. **Review specs** - Context is crucial
5. **Commit often** - Track progress

## Documentation

All implementation details are in `/spec/`:
- `claude-code-implementation-plan.md` - 25 sessions
- `claude-code-session-templates.md` - Prompt templates
- `technical-implementation-guide.md` - Code patterns
- `mvp-user-stories.md` - Requirements

## Support

If a session fails:
1. Check prerequisites are met
2. Verify context files exist
3. Review error messages
4. Run with more constraints

Remember: The goal is a stable MVP in 10-15 days of focused development.