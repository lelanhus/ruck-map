# Terrain Override System Implementation

## Overview

This document describes the implementation of the SwiftUI terrain override system for the RuckMap application. The system provides manual terrain selection with haptic feedback, army green design system colors, gesture-based interactions, and auto-revert functionality.

## Architecture

### MV (Model-View) Pattern with @Observable

The implementation follows modern SwiftUI architecture patterns using the @Observable macro instead of traditional MVVM:

- **TerrainOverrideState**: @Observable state manager for terrain override functionality
- **TerrainOverrideView**: Main SwiftUI view with declarative UI and gesture handling
- **Compatibility Layer**: Bridges the new system with existing LocationTrackingManager

### Key Components

1. **Army Green Design System**: Comprehensive color palette with adaptive iOS 18+ color mixing
2. **Terrain Override State Management**: Auto-revert timers and duration tracking
3. **Haptic Feedback Integration**: CoreHaptics for enhanced user experience
4. **Gesture Recognition**: Long press and tap gestures for quick access
5. **Accessibility Support**: Full VoiceOver and accessibility trait support

## Implementation Details

### Army Green Design System

```swift
struct ArmyGreenDesign {
    // Base army green palette
    static let primary = Color(red: 0.2, green: 0.3, blue: 0.2)       // #334D33
    static let secondary = Color(red: 0.3, green: 0.4, blue: 0.3)     // #4D664D
    static let accent = Color(red: 0.6, green: 0.7, blue: 0.5)        // #99B380
    
    // iOS 18+ adaptive variations using color mixing
    static let primaryLight = primary.mix(with: .white, by: 0.3)
    static let primaryDark = primary.mix(with: .black, by: 0.2)
    
    // Hierarchical variations for text
    static let textPrimary = primary
    static let textSecondary = primary.secondary
    static let textTertiary = primary.tertiary
}
```

### Terrain Override State Management

The `TerrainOverrideState` class manages:
- Active override status and duration
- Auto-revert timer functionality
- Quick picker visibility
- Remaining time calculations

```swift
@Observable
final class TerrainOverrideState {
    var isOverrideActive: Bool = false
    var overrideStartTime: Date?
    var overrideDuration: TimeInterval = 600 // 10 minutes
    
    func startOverride(terrain: TerrainType, duration: TimeInterval = 600) {
        // Sets terrain, starts timer, updates UI state
    }
    
    func clearOverride() {
        // Clears override, invalidates timer, resets state
    }
}
```

### Gesture-Based Interaction

The system supports two primary gestures:
- **Tap**: Toggles quick picker or clears active override
- **Long Press** (0.6s): Opens terrain selection interface

```swift
.onLongPressGesture(minimumDuration: 0.6) {
    triggerHapticFeedback(.selection)
    withAnimation(.easeInOut(duration: 0.3)) {
        overrideState.showQuickPicker.toggle()
    }
}
```

### Haptic Feedback Integration

Three types of haptic feedback enhance user experience:
- **Selection**: Light feedback for picker interactions
- **Medium**: Confirmation feedback for terrain selection
- **Warning**: Alert feedback for override clearing

```swift
private func triggerHapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
    let impactFeedback = UIImpactFeedbackGenerator(style: type)
    impactFeedback.impactOccurred()
}
```

### Auto-Revert Functionality

The system automatically reverts to automatic terrain detection after a configurable duration:
- Default: 10 minutes
- Configurable: 5, 10, 15, or 30 minutes
- Timer invalidation on manual clear

```swift
private func startAutoRevertTimer() {
    autoRevertTimer?.invalidate()
    autoRevertTimer = Timer.scheduledTimer(withTimeInterval: overrideDuration, repeats: false) { [weak self] _ in
        Task { @MainActor in
            self?.clearOverride()
        }
    }
}
```

## UI Components

### TerrainDisplayCard

Main terrain information display with:
- Current terrain type and icon
- Confidence indicator or remaining override time
- Visual feedback for override status
- Gradient background with army green colors

### TerrainQuickSelectButton

Individual terrain selection buttons featuring:
- SF Symbol icons for each terrain type
- Terrain factor multiplier display
- Army green color theming
- Scale animation on selection
- Full accessibility support

### TerrainOverlay

Compact overlay for the main tracking screen:
- Minimal visual footprint
- Long press gesture activation
- Sheet presentation for full interface
- Remaining time display when active

## Compatibility Layer

To integrate with the existing LocationTrackingManager, a compatibility layer provides:

```swift
struct TerrainOverrideCompatState {
    private let locationManager: LocationTrackingManager
    
    var isOverrideActive: Bool {
        locationManager.isTerrainOverrideActive
    }
    
    var selectedTerrain: TerrainType {
        get { locationManager.currentDetectedTerrain }
        set { locationManager.setManualTerrainOverride(newValue) }
    }
}
```

## Accessibility Features

The implementation includes comprehensive accessibility support:

### VoiceOver Support
- Descriptive accessibility labels for all interactive elements
- Accessibility hints explaining available actions
- Proper accessibility traits (`.isSelected` for active terrain)

### Dynamic Type Support
- All text scales with user preferences
- Maintains visual hierarchy at all sizes

### Color Accessibility
- High contrast color combinations
- Support for increased contrast accessibility setting
- Semantic color meanings maintained across themes

## iOS 26 Liquid Glass Preparation

The implementation prepares for iOS 26's Liquid Glass design system:

### Material Usage
- Background materials that adapt to interface elevation
- Translucent overlays with proper vibrancy
- Shadow and blur effects for depth

### Adaptive Colors
- Color mixing API usage for dynamic palette generation
- Hierarchical color system compatibility
- Automatic dark mode adaptation

### Animation System
- SwiftUI's native animation system
- Symbol effects for enhanced visual feedback
- Smooth transitions between states

## Testing Strategy

Comprehensive test coverage using Swift Testing framework:

### Unit Tests
- Army green color system validation
- Terrain override state management
- Remaining time calculations
- Auto-revert timer functionality

### Integration Tests
- Full terrain override workflow
- Compatibility layer functionality
- UI component integration

### Performance Tests
- Rapid state change handling
- Color calculation optimization
- Memory usage validation

### Accessibility Tests
- VoiceOver navigation
- Dynamic type scaling
- High contrast support

## Usage Examples

### Basic Implementation
```swift
struct TrackingView: View {
    let terrainDetector: TerrainDetector
    
    var body: some View {
        ZStack {
            // Main tracking interface
            TrackingContentView()
            
            // Terrain override overlay
            TerrainOverlay(terrainDetector: terrainDetector)
        }
    }
}
```

### With LocationTrackingManager
```swift
struct ActiveTrackingView: View {
    @State var locationManager: LocationTrackingManager
    
    var body: some View {
        VStack {
            // Tracking content
        }
        .overlay(alignment: .topTrailing) {
            if locationManager.trackingState == .tracking {
                TerrainOverlayCompat(locationManager: locationManager)
            }
        }
    }
}
```

## Performance Considerations

### Optimizations Applied
- Lazy loading of terrain picker interface
- Efficient state change handling
- Cached color calculations
- Minimal view updates through @Observable

### Memory Management
- Proper timer invalidation
- Weak references in closures
- Efficient state cleanup

## Future Enhancements

### Planned Features
- Custom terrain type creation
- GPS-based automatic override suggestions
- Historical override pattern analysis
- Machine learning terrain prediction improvements

### iOS 26 Features
- Liquid Glass material adoption
- Enhanced symbol effects
- Advanced haptic patterns
- Spatial computing compatibility

## Conclusion

The terrain override system provides a comprehensive, accessible, and performant solution for manual terrain selection in the RuckMap application. The implementation follows modern SwiftUI patterns, supports current and future iOS versions, and maintains consistency with the army green design system while providing excellent user experience through haptic feedback and gesture-based interaction.