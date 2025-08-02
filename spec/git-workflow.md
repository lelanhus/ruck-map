# RuckMap Git Workflow for Claude Code Sessions

## Branch Strategy

### Main Branches
- `main` - Production-ready code (protected)
- `develop` - Integration branch for completed features
- `session/*` - Feature branches for each Claude Code session

### Branch Naming Convention
```
session/01-project-setup
session/02-location-tracking
session/03-gps-optimization
...
session/25-app-store-submission
```

## Workflow Per Session

### 1. Before Starting a Session
```bash
# Ensure you're on develop
git checkout develop
git pull origin develop

# Create session branch
git checkout -b session/XX-feature-name

# Example for Session 6
git checkout -b session/06-calorie-algorithm
```

### 2. During the Session
Claude Code will make commits throughout the implementation:
```bash
# Claude Code commits as it completes components
git add .
git commit -m "feat: implement LocationTrackingManager with background support"

git add .
git commit -m "test: add unit tests for distance calculation"

git add .
git commit -m "fix: optimize battery usage with adaptive sampling"
```

### 3. After Session Completion
```bash
# Push session branch
git push -u origin session/XX-feature-name

# Create PR to develop
gh pr create --base develop --title "Session XX: Feature Name" --body "
## Session XX Implementation

### Completed:
- [ ] Core implementation
- [ ] Unit tests (>80% coverage)
- [ ] Performance targets met
- [ ] No memory leaks

### Key Metrics:
- Battery usage: X%/hour
- Test coverage: X%
- Performance: Xfps

### Changes:
- Brief description of what was implemented

Closes #XX"
```

## Commit Message Format

Follow conventional commits:
```
feat: add calorie calculation algorithm
fix: reduce GPS battery usage to <10%/hour  
test: add integration tests for HealthKit
docs: update API documentation
refactor: optimize SwiftData queries
perf: improve launch time to <2 seconds
```

## PR Review Checklist

Before merging session PRs to develop:
- [ ] All tests pass
- [ ] Performance metrics met
- [ ] No merge conflicts
- [ ] Code follows Swift style guide
- [ ] Documentation updated

## Phase Completion

After completing a phase (e.g., Sessions 1-5):
```bash
# Create phase release
git checkout develop
git pull origin develop
git tag -a v0.1.0-foundation -m "Phase 1: Foundation Complete"
git push origin v0.1.0-foundation
```

## Handling Failures

If a session fails or needs rework:
```bash
# Option 1: Fix in same branch
git checkout session/XX-feature-name
# Make fixes
git add .
git commit -m "fix: address performance issues in feature"
git push

# Option 2: Abandon and restart
git checkout develop
git branch -D session/XX-feature-name
git push origin --delete session/XX-feature-name
# Start fresh with new session
```

## Integration Points

### Daily Integration
```bash
# Each morning, sync develop
git checkout develop
git pull origin develop

# Rebase active session branches
git checkout session/XX-current
git rebase develop
```

### Conflict Resolution
If conflicts arise during rebase:
1. Resolve conflicts favoring completed, tested code
2. Re-run tests after resolution
3. Verify performance metrics still met

## Release Process

### Beta Release (After Session 24)
```bash
git checkout develop
git checkout -b release/1.0.0-beta
# Final testing and fixes
git tag -a v1.0.0-beta.1 -m "Beta Release 1"
```

### Production Release (After Session 25)
```bash
git checkout main
git merge --no-ff release/1.0.0-beta
git tag -a v1.0.0 -m "Initial Release"
git push origin main --tags
```

## Quick Reference

```bash
# Start new session
git checkout -b session/XX-name

# Check current session
git branch --show-current

# See all session branches
git branch -a | grep session/

# Clean up merged sessions
git branch -d session/XX-name
git push origin --delete session/XX-name
```

## Git Aliases for Efficiency

Add to your git config:
```bash
git config --global alias.session "checkout -b"
git config --global alias.sessions "branch -a | grep session/"
git config --global alias.session-clean "!git branch --merged | grep session/ | xargs -n 1 git branch -d"
```

Usage:
```bash
git session session/07-terrain-detection
git sessions  # List all session branches
git session-clean  # Delete merged session branches
```

## Important Notes

1. **Never commit directly to main or develop** - Always use session branches
2. **One session = One PR** - Don't combine multiple sessions
3. **Test before pushing** - Ensure all metrics are met
4. **Document decisions** - Use detailed commit messages
5. **Squash commits if needed** - But preserve important history

This workflow ensures clean history, easy rollbacks, and clear progress tracking through the 25-session plan.