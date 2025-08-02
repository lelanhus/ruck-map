# SwiftUI Accessibility Excellence Guide

## Overview

Accessibility is not just about compliance—it's about creating an inclusive experience for all users. This guide covers comprehensive accessibility implementation in SwiftUI for iOS 18+.

## VoiceOver Implementation

### Basic VoiceOver Support

```swift
struct AccessibleRuckCard: View {
    let session: RuckSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "figure.walk")
                Text("\(session.distance, specifier: "%.2f") miles")
                    .font(.headline)
            }
            
            Text("Weight: \(session.weight, specifier: "%.0f") lbs")
                .font(.subheadline)
        }
        .padding()
        .background(Color.secondarySystemBackground)
        .cornerRadius(12)
        // Combine elements for VoiceOver
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
    }
    
    private var accessibilityDescription: String {
        let dateString = session.date.formatted(date: .abbreviated, time: .shortened)
        let distanceString = "\(session.distance.formatted()) miles"
        let weightString = "\(session.weight.formatted()) pounds"
        let durationString = session.duration.formatted()
        
        return "Ruck session on \(dateString). Distance: \(distanceString), weight carried: \(weightString), duration: \(durationString)"
    }
}
```

### Custom Accessibility Actions

```swift
struct RuckRowWithActions: View {
    let ruck: RuckSession
    @State private var isFavorite = false
    @State private var showingShareSheet = false
    
    var body: some View {
        HStack {
            RuckInfo(ruck: ruck)
            Spacer()
            
            // Visual buttons hidden from VoiceOver
            HStack(spacing: 16) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                .accessibilityHidden(true)
                
                Button(action: shareRuck) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ruck.accessibilityLabel)
        .accessibilityActions {
            Button(isFavorite ? "Remove from favorites" : "Add to favorites") {
                toggleFavorite()
            }
            
            Button("Share") {
                shareRuck()
            }
            
            Button("Delete") {
                deleteRuck()
            }
        }
    }
}
```

### Accessibility Rotor

```swift
struct RuckHistoryView: View {
    let rucks: [RuckSession]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(rucks) { ruck in
                    RuckCard(ruck: ruck)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(ruck.accessibilityLabel)
                }
            }
        }
        .accessibilityRotor("Favorite Rucks") {
            ForEach(favoriteRucks) { ruck in
                AccessibilityRotorEntry(ruck.title, id: ruck.id)
            }
        }
        .accessibilityRotor("This Week") {
            ForEach(thisWeekRucks) { ruck in
                AccessibilityRotorEntry(ruck.title, id: ruck.id)
            }
        }
    }
    
    private var favoriteRucks: [RuckSession] {
        rucks.filter { $0.isFavorite }
    }
    
    private var thisWeekRucks: [RuckSession] {
        let weekAgo = Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
        return rucks.filter { $0.date > weekAgo }
    }
}
```

## Dynamic Type Implementation

### Scaled Values

```swift
struct ScaledMetrics {
    @ScaledMetric private var spacing: CGFloat = 16
    @ScaledMetric private var padding: CGFloat = 20
    @ScaledMetric private var iconSize: CGFloat = 24
    @ScaledMetric private var cornerRadius: CGFloat = 12
    
    // Relative to specific text styles
    @ScaledMetric(relativeTo: .headline) private var headlineSpacing: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var bodyLineSpacing: CGFloat = 4
}

struct DynamicTypeView: View {
    @ScaledMetric private var imageSize: CGFloat = 60
    @ScaledMetric private var spacing: CGFloat = 16
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        HStack(spacing: spacing) {
            Image(systemName: "figure.walk")
                .font(.system(size: imageSize))
                .foregroundColor(.accentColor)
                .frame(width: imageSize, height: imageSize)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Ruck")
                    .font(.headline)
                    .lineLimit(sizeCategory.isAccessibilityCategory ? 2 : 1)
                
                Text("3.2 miles • 45 lbs • 52:30")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !sizeCategory.isAccessibilityCategory {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding()
    }
}
```

### Adaptive Layouts for Large Text

```swift
struct AdaptiveRuckStats: View {
    let stats: RuckStatistics
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        if sizeCategory.isAccessibilityCategory {
            // Vertical layout for large text
            VStack(alignment: .leading, spacing: 16) {
                StatItem(title: "Total Distance", value: stats.formattedDistance)
                StatItem(title: "Total Time", value: stats.formattedTime)
                StatItem(title: "Avg Pace", value: stats.formattedPace)
                StatItem(title: "Calories", value: stats.formattedCalories)
            }
        } else {
            // Grid layout for regular text
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatItem(title: "Total Distance", value: stats.formattedDistance)
                StatItem(title: "Total Time", value: stats.formattedTime)
                StatItem(title: "Avg Pace", value: stats.formattedPace)
                StatItem(title: "Calories", value: stats.formattedCalories)
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
```

## Color and Contrast

### High Contrast Support

```swift
struct ContrastAwareColors {
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    var primaryButtonColor: Color {
        switch colorSchemeContrast {
        case .standard:
            return .armyGreen
        case .increased:
            return Color(red: 0.2, green: 0.25, blue: 0.1) // Darker army green
        @unknown default:
            return .armyGreen
        }
    }
    
    var borderColor: Color {
        colorSchemeContrast == .increased ? .primary : .secondary
    }
    
    var borderWidth: CGFloat {
        colorSchemeContrast == .increased ? 2 : 1
    }
}

struct ContrastAwareButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorSchemeContrast) var contrast
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(backgroundView)
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if contrast == .increased {
            // High contrast: solid color with border
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
        } else {
            // Standard contrast
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.armyGreen)
        }
    }
}
```

### Color Accessibility

```swift
extension Color {
    // WCAG compliant color pairs
    static let accessiblePairs = [
        (foreground: Color.white, background: Color.armyGreen),
        (foreground: Color.black, background: Color.armyTan),
        (foreground: Color.armyGreen, background: Color.white)
    ]
    
    // Semantic colors with guaranteed contrast
    static var primaryActionColor: Color {
        Color("PrimaryAction") // Define in Assets with Any/Dark/High Contrast variants
    }
    
    static var warningColor: Color {
        // Ensure 3:1 contrast ratio for graphics
        Color(red: 0.9, green: 0.6, blue: 0.0)
    }
}

struct AccessibleColorView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Always test color combinations
            Text("Important Message")
                .foregroundColor(.white)
                .padding()
                .background(Color.armyGreen)
                .accessibilityLabel("Important: Message content here")
            
            // Use symbols for additional clarity
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.warningColor)
                Text("Warning: Low battery")
                    .foregroundColor(.primary)
            }
        }
    }
}
```

## Focus Management

### Accessibility Focus

```swift
struct FormWithFocusManagement: View {
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @AccessibilityFocusState private var isErrorFocused: Bool
    @AccessibilityFocusState private var isUsernameFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if showError {
                Text("Please enter valid credentials")
                    .foregroundColor(.red)
                    .accessibilityFocused($isErrorFocused)
            }
            
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .accessibilityFocused($isUsernameFocused)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("Login") {
                if username.isEmpty || password.isEmpty {
                    showError = true
                    isErrorFocused = true
                    
                    // Announce error to VoiceOver
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Please enter valid credentials"
                    )
                } else {
                    login()
                }
            }
        }
        .padding()
        .onAppear {
            isUsernameFocused = true
        }
    }
}
```

### Navigation Announcements

```swift
struct NavigationWithAnnouncements: View {
    @State private var currentScreen = "Home"
    
    var body: some View {
        NavigationStack {
            HomeView()
                .onAppear {
                    announceScreenChange("Home Screen")
                }
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "profile":
                        ProfileView()
                            .onAppear {
                                announceScreenChange("Profile Screen")
                            }
                    case "settings":
                        SettingsView()
                            .onAppear {
                                announceScreenChange("Settings Screen")
                            }
                    default:
                        EmptyView()
                    }
                }
        }
    }
    
    private func announceScreenChange(_ screenName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(
                notification: .screenChanged,
                argument: screenName
            )
        }
    }
}
```

## Reduce Motion Support

### Motion-Sensitive Animations

```swift
struct MotionSensitiveView: View {
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack {
            Button("Toggle") {
                isExpanded.toggle()
            }
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.armyGreen)
                .frame(height: isExpanded ? 200 : 100)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.5),
                    value: isExpanded
                )
            
            // Alternative for complex animations
            if !reduceMotion {
                LoadingSpinner()
            } else {
                Text("Loading...")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CrossfadeTransition: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isActive ? 1 : 0.8))
            .animation(
                reduceMotion ? .linear(duration: 0.1) : .spring(),
                value: isActive
            )
    }
}
```

## Testing Accessibility

### Accessibility Inspector Testing

```swift
#if DEBUG
struct AccessibilityTestView: View {
    var body: some View {
        VStack {
            // Test with Accessibility Inspector
            Button("Test Button") {
                print("Tapped")
            }
            .accessibilityIdentifier("test_button") // For UI testing
            .accessibilityLabel("Test action button")
            .accessibilityHint("Performs a test action")
            .accessibilityValue("Not pressed")
        }
    }
}
#endif
```

### Automated Accessibility Testing

```swift
import XCTest

class AccessibilityUITests: XCTestCase {
    func testVoiceOverNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Enable VoiceOver for testing
        app.launchArguments = ["-UIAccessibilityVoiceOverEnabled", "1"]
        
        // Test accessibility labels
        XCTAssertTrue(app.buttons["Start Ruck"].exists)
        XCTAssertTrue(app.staticTexts["Total Distance: 45.3 miles"].exists)
        
        // Test navigation
        app.buttons["Start Ruck"].tap()
        XCTAssertTrue(app.navigationBars["Active Ruck"].exists)
    }
    
    func testDynamicType() throws {
        let app = XCUIApplication()
        
        // Test different text sizes
        let textSizes = [
            "-UIPreferredContentSizeCategoryName": [
                "UICTContentSizeCategoryXS",
                "UICTContentSizeCategoryXXXL",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        ]
        
        for (key, sizes) in textSizes {
            for size in sizes {
                app.launchArguments = [key, size]
                app.launch()
                
                // Take screenshots for manual review
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "DynamicType-\(size)"
                attachment.lifetime = .keepAlways
                add(attachment)
                
                app.terminate()
            }
        }
    }
}
```

### Manual Testing Checklist

```swift
struct AccessibilityChecklist {
    static let voiceOverTests = [
        "All interactive elements are accessible",
        "Labels are descriptive and concise",
        "Hints provide additional context where needed",
        "Custom actions are available for complex interactions",
        "Navigation order is logical",
        "Announcements are made for important changes"
    ]
    
    static let dynamicTypeTests = [
        "Text scales appropriately",
        "Layouts adapt to larger text sizes",
        "No text truncation at maximum sizes",
        "Images scale with text where appropriate",
        "Minimum touch targets maintained"
    ]
    
    static let colorTests = [
        "Sufficient contrast ratios (4.5:1 for normal text)",
        "Information not conveyed by color alone",
        "High contrast mode supported",
        "Dark mode properly implemented"
    ]
    
    static let motionTests = [
        "Reduce Motion preference respected",
        "Alternative static UI provided",
        "Essential animations preserved",
        "No motion sickness triggers"
    ]
}
```

## Best Practices

### 1. Accessibility-First Development

```swift
// Build with accessibility in mind from the start
struct AccessibleComponent: View {
    let data: ComponentData
    
    var body: some View {
        // Visual implementation
        visualContent
            // Accessibility layer
            .accessibilityElement(children: .combine)
            .accessibilityLabel(data.accessibilityLabel)
            .accessibilityValue(data.accessibilityValue)
            .accessibilityHint(data.accessibilityHint)
            .accessibilityTraits(data.accessibilityTraits)
    }
}
```

### 2. Meaningful Labels

```swift
// ❌ Bad: Generic labels
Image(systemName: "star.fill")
    .accessibilityLabel("Star")

// ✅ Good: Contextual labels
Image(systemName: "star.fill")
    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
```

### 3. Grouped Content

```swift
// Group related content for easier navigation
HStack {
    Image(systemName: "location")
    Text("Fort Bragg")
    Text("•")
    Text("3.2 miles")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Location: Fort Bragg, Distance: 3.2 miles")
```

### 4. Progressive Enhancement

```swift
struct ProgressiveView: View {
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
    
    var body: some View {
        if voiceOverEnabled {
            // Simplified, VoiceOver-optimized layout
            SimplifiedLayout()
        } else {
            // Rich visual layout
            StandardLayout()
        }
    }
}
```

## Conclusion

Accessibility is a fundamental aspect of iOS development. Key principles:

1. **Design for everyone** from the start
2. **Test with real assistive technologies**
3. **Provide multiple ways** to accomplish tasks
4. **Never rely solely on visual cues**
5. **Continuously improve** based on user feedback

Remember: An accessible app is a better app for everyone.