# /ruck-pr

Create or manage pull requests for completed RuckMap sessions.

## Usage

```
/ruck-pr create           # Create PR for current session branch
/ruck-pr list            # List all open session PRs
/ruck-pr merge [number]  # Merge a session PR
/ruck-pr status          # Check PR readiness
```

## Creating a PR

### `/ruck-pr create`
Creates a pull request from current session branch to develop.

**What it does:**
1. Verifies all tests pass
2. Checks performance metrics
3. Ensures git history is clean
4. Creates PR with session template
5. Adds appropriate labels

**PR Template Used:**
```markdown
## Session XX: [Feature Name]

### ✅ Completed
- [x] Core implementation per spec
- [x] Unit tests with X% coverage
- [x] Performance targets met
- [x] No memory leaks
- [x] Documentation updated

### 📊 Metrics
- Battery Usage: X%/hour (target: <10%)
- Test Coverage: X% (target: >80%)
- UI Performance: Xfps (target: 60)
- Memory Peak: XMB (target: <100MB)
- Crash Rate: 0% (target: <0.1%)

### 🔄 Changes
- Brief description of what was implemented
- Key technical decisions made
- Any deviations from spec

### 🧪 Testing
- How to test the feature
- Edge cases covered
- Performance validated under conditions

### 📸 Screenshots
[If applicable, UI changes]

### 🔗 Related
- Implements spec: `spec/mvp-user-stories.md` Story X.X
- Closes #X
```

## PR Management

### `/ruck-pr list`
Shows all open session PRs with status:
```
Open Session PRs:
================
#12 session/06-calorie-algorithm ✅ Ready to merge (3 approvals)
#13 session/07-terrain-detection ⏳ In review (1 approval needed)
#14 session/08-weather-integration ❌ Tests failing
```

### `/ruck-pr merge [number]`
Safely merges a session PR:
1. Checks all CI passes
2. Ensures no conflicts with develop
3. Squashes commits if needed
4. Merges with conventional commit
5. Deletes session branch
6. Updates local develop

### `/ruck-pr status`
Checks if current branch is ready for PR:
```
PR Readiness Check:
==================
✅ All tests passing
✅ Performance targets met
✅ Clean git history
❌ Missing documentation updates
✅ No merge conflicts with develop

Status: Fix documentation before creating PR
```

## Automated Checks

Each PR automatically validates:
- [ ] SwiftLint passes
- [ ] Unit test coverage >80%
- [ ] UI tests pass
- [ ] No memory leaks
- [ ] Battery usage <10%/hour
- [ ] Launch time <2 seconds
- [ ] 60fps UI performance

## Labels Applied

PRs are auto-labeled:
- `session-XX` - Session number
- `phase-1` through `phase-5` - Development phase
- `ready-to-merge` - All checks pass
- `needs-review` - Awaiting review
- `performance` - Meets metrics

## Merge Strategy

### For Feature Sessions (1-23)
- Merge to `develop` branch
- Squash merge optional
- Delete session branch after merge

### For Release Sessions (24-25)
- Create release branch first
- No squash merge
- Tag after merge

## Common Issues

### Tests Failing
```bash
# Fix locally
git checkout session/XX-name
# Make fixes
git add .
git commit -m "fix: resolve test failures"
git push
```

### Merge Conflicts
```bash
# Rebase on latest develop
git checkout session/XX-name
git fetch origin
git rebase origin/develop
# Resolve conflicts
git push --force-with-lease
```

### Performance Regression
```bash
# Profile and fix
/ruck-quick fix performance
git add .
git commit -m "perf: optimize to meet targets"
git push
```

## Best Practices

1. **One session = One PR** - Don't combine sessions
2. **Test before PR** - Run `/ruck-test all`
3. **Clean history** - Use descriptive commits
4. **Update specs** - If implementation differs
5. **Document decisions** - In PR description

## Integration with CI/CD

The PR triggers:
1. GitHub Actions test suite
2. Performance benchmarks
3. Code coverage reports
4. SwiftLint validation
5. Memory leak detection

Results appear as PR checks within 10-15 minutes.

This command ensures consistent, high-quality pull requests throughout the RuckMap development process.