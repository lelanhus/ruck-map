# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RuckMap is an iOS fitness application for the rucking community, featuring:
- Ruck logging with scientifically backed calorie calculations (RUCKCAL™)
- GPS route tracking with elevation and speed data
- HealthKit integration
- Community features and challenges
- SwiftUI with upcoming Liquid Glass design system
- Swift 6 with actor-based concurrency

## Key Technologies

- **Language**: Swift 6
- **UI Framework**: SwiftUI (with Liquid Glass components when available)
- **Data**: SwiftData with CloudKit sync
- **Architecture**: SwiftUI MV pattern with unidirectional data flow
- **Testing**: Swift Testing framework (iOS 17+)
- **Analytics**: TelemetryDeck
- **User Feedback**: WishKit
- **Monetization**: RevenueCat
- **Crash Reporting**: Firebase Crashlytics

## Development Commands

Since this is a new iOS project without an Xcode project yet:

```bash
# Create new Xcode project (when starting development)
# File > New > Project > iOS App
# Product Name: RuckMap
# Organization Identifier: com.ruckmap
# Interface: SwiftUI
# Language: Swift
# Use Core Data: No (using SwiftData)

# Open project
open RuckMap.xcodeproj

# Run tests (once project exists)
# Cmd+U in Xcode or:
xcodebuild test -scheme RuckMap -destination 'platform=iOS Simulator,name=iPhone 15'

# Build project
xcodebuild build -scheme RuckMap -destination 'platform=iOS Simulator,name=iPhone 15'

# SwiftLint (after adding via SPM)
swiftlint
```

## Architecture Overview

The app follows a modular architecture organized by feature:

- **Core**: Shared models, extensions, and utilities
- **Features**: Modular features (Rucking, Routes, Community, Profile, etc.)
- **Services**: Data persistence, networking, location tracking
- **UI Components**: Reusable SwiftUI components with army green theme

Each feature module contains:
- Views (SwiftUI views)
- Models (domain models)
- ViewModels (if needed for complex state)
- Services (feature-specific business logic)

## User Personas

The app targets five key personas:
1. Military Veterans (primary) - Focus on PT standards, unit challenges
2. Fitness Enthusiast Parents - Family-friendly routes, safety features
3. Young Urban Professionals - Social features, city routes
4. Health-Conscious Retirees - Health monitoring, gentle progression
5. Outdoor Adventure Seekers - Offline maps, trail integration

## Important Implementation Notes

- Prioritize UI/UX implementation first
- Use Swift Testing framework for TDD approach
- Army green color scheme throughout (see ai-docs/planning/swiftui-army-green-components.md)
- Implement proper actor isolation for concurrent operations
- Support offline functionality for outdoor scenarios
- Follow Apple Human Interface Guidelines
- Ensure accessibility compliance (VoiceOver, Dynamic Type)
- Follow the Google Swift Style Guide

## Current Project Status

- Planning phase complete
- Comprehensive requirements and architecture documented
- No code implementation yet
- Ready to begin Xcode project setup and UI development

## Build Configuration

- We will use xcodegen to build the project
- Follow the Google Swift Style Guide

## Available Sub-Agents

The project includes specialized sub-agents for iOS development tasks:

### Planning & Architecture
- **ios-architecture**: Swift 6+ concurrency patterns and SwiftUI architecture
- **swiftdata-architecture**: SwiftData model architecture and CloudKit integration
- **technical-implementation**: Implementation guides and testing strategies
- **wireframing-ios-design**: iOS wireframing and Human Interface Guidelines compliance

### Development & Implementation
- **swift-implementation**: Swift/SwiftUI code implementation following Google Style Guide
- **swift-testing**: Swift Testing framework tests with 80%+ coverage target
- **xcodegen-manager**: XcodeGen project configuration management
- **swiftui-accessibility**: Accessibility compliance for SwiftUI components
- **ios-commit**: Semantic git commits with iOS-specific context

### Research & Analysis
- **competitive-analysis**: Market analysis using Porter's Five Forces
- **persona-research**: User persona creation and journey mapping
- **problem-validation**: Problem validation and documentation
- **information-architecture**: Information architecture and user flow optimization

### Requirements & Documentation
- **functional-requirements**: INVEST-compliant user stories and acceptance criteria
- **quality-requirements**: Non-functional requirements and performance benchmarks
- **prototype-validation**: Interactive prototyping and validation testing

## Using Sub-Agents

Sub-agents can be invoked automatically by Claude or explicitly:

```bash
# Automatic invocation - Claude will use appropriate agents
"Create the LocationTrackingActor service"

# Explicit invocation
"Use the swift-implementation agent to create LocationTrackingActor"
```

### Common Workflows

1. **Feature Implementation**
   ```
   1. ios-architecture designs the actor system
   2. swift-implementation creates the code
   3. swift-testing writes comprehensive tests
   4. swiftui-accessibility ensures accessibility
   5. ios-commit creates semantic commits
   ```

2. **UI Component Creation**
   ```
   1. wireframing-ios-design creates wireframes
   2. swift-implementation builds SwiftUI views
   3. swiftui-accessibility adds accessibility
   4. swift-testing creates UI tests
   ```

3. **Project Setup**
   ```
   1. xcodegen-manager creates project.yml
   2. xcodegen-manager adds dependencies
   3. swift-implementation creates initial structure
   ```