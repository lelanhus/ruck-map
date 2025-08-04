# RuckMap Watch App

A standalone Apple Watch application for tracking ruck marches with GPS, heart rate monitoring, and calorie tracking.

## Features

### Core Functionality
- **Standalone GPS Tracking**: Track rucks without iPhone dependency
- **Heart Rate Monitoring**: Real-time heart rate data via HealthKit
- **Calorie Calculation**: Military-grade LCDA algorithm optimized for loaded marching
- **Auto-Pause Detection**: Automatically pause tracking when stationary
- **Battery Optimization**: Adaptive GPS settings to preserve battery life

### User Interface
- **Digital Crown Navigation**: Optimized for one-handed operation
- **Real-time Metrics Display**: Distance, pace, calories, elevation, heart rate
- **Session History**: View recent ruck sessions (48-hour retention)
- **Simple Controls**: Start/pause/stop with large, accessible buttons

### Data Management
- **Local Storage**: 48-hour data retention on Watch
- **Automatic Cleanup**: Old sessions automatically removed to preserve storage
- **Efficient Data Models**: Optimized for Watch memory constraints

## Architecture

### Core Components

#### `WatchRuckSession` & `WatchLocationPoint`
- Lightweight SwiftData models optimized for Watch storage
- Essential metrics only to minimize memory footprint
- Automatic relationship management

#### `WatchLocationManager`
- Standalone GPS tracking with battery optimization
- Auto-pause functionality with movement detection
- Real-time metrics calculation and updates

#### `WatchCalorieCalculator`
- Simplified LCDA algorithm implementation
- Optimized for Watch processing constraints
- Real-time calorie burn rate calculation

#### `WatchHealthKitManager`
- Heart rate monitoring during workouts
- Body metrics loading for accurate calorie calculations
- Workout session integration

#### `WatchDataManager`
- Local data persistence with automatic cleanup
- 48-hour retention policy
- Storage usage monitoring

### UI Components

#### `TrackingView`
- Primary interface for active ruck tracking
- Real-time metric display cards
- Large, accessible control buttons

#### `HistoryView`
- Recent session browsing
- Detailed session information sheets
- Compact metric display

#### `SettingsView`
- Permission management
- Storage information
- About information

## Technical Specifications

### Requirements
- watchOS 10.0+
- Apple Watch Series 4 or later (recommended)
- GPS-enabled Apple Watch

### Permissions
- **Location**: Required for GPS tracking
- **HealthKit**: Optional for heart rate and body metrics

### Performance Optimizations
- **Battery Life**: Adaptive GPS accuracy based on movement patterns
- **Memory Usage**: Lightweight data models with essential fields only
- **Storage**: Automatic cleanup after 48 hours
- **UI Responsiveness**: Optimized update intervals for Watch constraints

### Data Retention
- Sessions stored locally for 48 hours
- Automatic cleanup to prevent storage overflow
- No cloud sync (iPhone app handles data persistence)

## Usage

### Starting a Ruck
1. Open RuckMap on Apple Watch
2. Tap "Start Ruck"
3. Set load weight using Digital Crown or buttons
4. Grant location permissions if prompted
5. Begin tracking

### During a Ruck
- View real-time metrics on main screen
- Digital Crown to scroll through metric cards
- Automatic pause detection when stationary
- Manual pause/resume via control buttons

### Stopping a Ruck
1. Tap "Stop" button
2. Confirm stop action
3. Session automatically saved locally
4. View in History tab

## Future Enhancements

### Planned Features
- **WatchConnectivity**: Sync with iPhone app
- **Complications**: Watch face integration
- **Advanced Metrics**: Terrain detection, weather integration
- **Haptic Feedback**: Pace alerts and notifications
- **Offline Maps**: Basic route visualization

### Technical Improvements
- **Background Refresh**: Continue tracking when app backgrounded
- **Cellular Independence**: Full standalone operation on cellular models
- **Advanced Battery Management**: Ultra-low power modes for extended tracking

## Development Notes

### Project Structure
```
RuckMapWatch/
├── Shared/                 # Shared models and utilities
│   ├── WatchModels.swift
│   ├── WatchLocationManager.swift
│   ├── WatchCalorieCalculator.swift
│   ├── WatchHealthKitManager.swift
│   └── WatchFormatUtilities.swift
└── Info.plist

RuckMapWatchExtension/
├── Views/                  # SwiftUI views
│   ├── TrackingView.swift
│   ├── HistoryView.swift
│   └── SettingsView.swift
├── RuckMapWatchApp.swift   # App entry point
├── ContentView.swift       # Main content view
├── ExtensionDelegate.swift # Extension lifecycle
└── Info.plist
```

### Testing Recommendations
- Test on multiple Watch sizes (40mm, 44mm, 45mm, 49mm)
- Verify battery life under various GPS conditions
- Test auto-pause functionality in real-world scenarios
- Validate HealthKit integration across different Watch models

### Known Limitations
- 48-hour data retention (by design for storage management)
- No offline map display (future enhancement)
- Simplified terrain detection (grade-based only)
- No WatchConnectivity sync (future enhancement)