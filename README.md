# RuckMap

An iOS application for tracking, planning, and improving ruck marches with military-grade accuracy.

## Project Status

🚧 **Pre-Development** - Comprehensive specifications complete, ready for implementation.

## Quick Start

See [`spec/START-HERE.md`](spec/START-HERE.md) for the complete implementation guide.

## Project Structure

```
ruck-map/
├── .claude/              # Claude Code configuration
│   ├── README.md        # Command documentation
│   └── slash-commands/  # Custom development commands
├── ai-docs/             # Research and planning documents
├── spec/                # Implementation specifications
│   ├── START-HERE.md    # 👈 Start here!
│   ├── claude-code-implementation-plan.md
│   └── ...
└── CLAUDE.md           # Claude Code guidance
```

## Git Workflow

This project uses a feature branch workflow:

- `main` - Production-ready code
- `develop` - Integration branch
- `session/*` - Feature branches for each development session

### Starting Development

```bash
# Ensure you're on develop
git checkout develop
git pull origin develop

# Start first session
/ruck-session 1
```

## Development Approach

Development is organized into 25 focused sessions, each producing a complete, tested component. Claude Code performs all implementation following the specifications in the `spec/` directory.

### Available Commands

- `/ruck-session [number]` - Start implementation session
- `/ruck-status` - Check progress
- `/ruck-test [component]` - Run tests
- `/ruck-pr create` - Create pull request

## Key Features

- **Military-Grade Accuracy**: LCDA-based calorie algorithm with <10% error
- **Advanced GPS Tracking**: Elevation, terrain detection, weather integration
- **Apple Watch App**: Standalone tracking with 6+ hour battery life
- **Unit Management**: First-of-its-kind team training coordination
- **HealthKit Integration**: Comprehensive fitness data sync

## Technical Stack

- **Language**: Swift 6
- **UI**: SwiftUI (iOS 18+)
- **Data**: SwiftData with CloudKit
- **Testing**: Swift Testing framework
- **Architecture**: Actor-based concurrency

## Success Metrics

- 🔋 Battery: <10% per hour
- 📱 Performance: 60fps UI
- 🧪 Tests: >80% coverage
- 💾 Memory: <100MB active
- ⏱️ Launch: <2 seconds
- 📊 Accuracy: <10% calorie error

## Contributing

This project is currently in initial development. See the implementation plan for details on the development process.

## License

Copyright © 2024 RuckMap. All rights reserved.