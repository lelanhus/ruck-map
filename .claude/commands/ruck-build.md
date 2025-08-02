---
description: Build RuckMap with various configurations and check for warnings/errors
allowed-tools: Bash, Read, Grep
argument-hint: "[debug|release|test|clean] [destination]"
---

# /ruck-build

Build RuckMap with proper configuration and comprehensive error checking.

## Usage

```
/ruck-build [configuration] [destination]
```

## Configurations

- `debug` - Debug build (default)
- `release` - Release build with optimizations
- `test` - Build for testing
- `clean` - Clean build folder
- `all` - Build all configurations

## Destinations

- `simulator` - iOS Simulator (default)
- `device` - Physical iOS device
- `mac` - Mac Catalyst
- `all` - All destinations

## Examples

```
/ruck-build                    # Debug build for simulator
/ruck-build release device     # Release build for device
/ruck-build test              # Build for testing
/ruck-build clean             # Clean and rebuild
```

## What This Command Does

1. **Regenerates Xcode project** with xcodegen if needed
2. **Runs SwiftLint** to check code quality
3. **Runs SwiftFormat** to ensure consistent formatting
4. **Builds the project** with specified configuration
5. **Captures all warnings** and errors
6. **Checks bundle size** for release builds
7. **Verifies entitlements** for capabilities

## Build Process

### Pre-Build Checks
- Verify xcodegen project.yml exists
- Check for uncommitted changes
- Validate Info.plist entries
- Ensure all required assets exist

### Build Execution
```bash
!xcodegen generate

!swiftlint --strict

!xcodebuild \
  -project RuckMap.xcodeproj \
  -scheme RuckMap \
  -configuration $CONFIGURATION \
  -destination '$DESTINATION' \
  clean build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  | xcbeautify
```

### Post-Build Analysis
- Count warnings and errors
- Check binary size (target: <50MB)
- Verify all capabilities are included
- Generate build report

## Output Format

```
RuckMap Build Report
===================

Configuration: Release
Destination: iOS Simulator
Duration: 45.2s

✅ Build Succeeded

Warnings: 3
- Unused variable 'oldLocation' (LocationTracker.swift:142)
- Force cast warning (RuckSession.swift:87)
- Deprecated API usage (MapView.swift:234)

Binary Size: 42.3 MB (Target: <50MB)

SwiftLint: 147 rules applied, 0 violations

Next Steps:
- Run tests: /ruck-test all
- Check performance: /ruck-performance
```

## Troubleshooting

Common issues handled:
- Missing provisioning profiles
- Simulator not available
- SwiftLint violations
- Module import errors
- Asset catalog issues

## Related Commands

- `/ruck-test` - Run tests after building
- `/ruck-performance` - Profile the build
- `/ruck-status` - Check project status

This command ensures consistent, high-quality builds across all team members.