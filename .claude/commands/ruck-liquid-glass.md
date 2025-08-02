---
description: Check and prepare RuckMap for iOS 26 Liquid Glass design system compatibility
allowed-tools: Task, Read, Write, Edit, MultiEdit, Grep, Glob
argument-hint: "[check|prepare|migrate] [component]"
---

# /ruck-liquid-glass

Analyze and prepare RuckMap for iOS 26 Liquid Glass design system compatibility.

## Usage

```
/ruck-liquid-glass [action] [component]
```

## Actions

- `check` - Analyze current implementation for Liquid Glass readiness
- `prepare` - Add conditional code for iOS 26 compatibility
- `migrate` - Convert existing components to Liquid Glass patterns

## Examples

```
/ruck-liquid-glass check           # Full compatibility check
/ruck-liquid-glass prepare cards   # Prepare card components
/ruck-liquid-glass migrate buttons # Migrate buttons to liquid animations
```

## What This Command Does

1. **Compatibility Analysis** (using swiftui-implementation-expert):
   - Reviews current material usage
   - Identifies components needing updates
   - Checks animation patterns
   - Evaluates performance impact

2. **Preparation Tasks**:
   - Adds `#available(iOS 26.0, *)` checks
   - Creates fallback implementations
   - Updates animation curves
   - Implements glass effect wrappers

3. **Migration Implementation**:
   - Converts `.material` to `.glassEffect()`
   - Updates animations to liquid patterns
   - Implements adaptive materials
   - Adds depth hierarchy

## Glass Effect Categories

### Primary Components
- Main tracking interface
- Route visualization overlay
- Stats dashboard

### Secondary Components
- Settings panels
- History cards
- Achievement badges

### Background Components
- Map overlays
- Weather indicators
- Terrain visualizers

## Implementation Checklist

The command will verify:
- [ ] Conditional API usage for iOS 26
- [ ] Progressive enhancement strategy
- [ ] Performance considerations
- [ ] Accessibility with glass effects
- [ ] Battery efficiency
- [ ] Semantic glass hierarchy
- [ ] Animation compatibility

## Design Tokens

Updates these design tokens for Liquid Glass:
```swift
struct DesignTokens {
    struct Glass {
        static let primaryIntensity = 0.7
        static let secondaryIntensity = 0.5
        static let backgroundIntensity = 0.3
    }
}
```

## Sub-Agent Usage

This command leverages:
- **swiftui-implementation-expert**: For UI migration strategies
- **performance-expert**: For glass effect performance analysis
- **accessibility-expert**: For maintaining accessibility with transparency

## Output Format

```
Liquid Glass Compatibility Report
================================

✅ Ready Components:
- [Component]: [Status]

⚠️ Needs Preparation:
- [Component]: [Required changes]

❌ Requires Migration:
- [Component]: [Migration strategy]

Performance Impact:
- Current: [Metrics]
- With Glass: [Projected metrics]

Recommendations:
1. [Priority actions]
2. [Migration order]
```

## Related Commands

- `/ruck-performance` - Check performance impact
- `/ruck-test ui` - Test UI after changes
- `/ruck-build` - Build with iOS 26 SDK

This command ensures RuckMap is ready for the next generation of iOS design while maintaining compatibility with current devices.