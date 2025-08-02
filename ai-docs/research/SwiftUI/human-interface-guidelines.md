# Apple Human Interface Guidelines for SwiftUI (iOS 18)

## Overview

The Human Interface Guidelines (HIG) are essential for creating intuitive, consistent, and beautiful iOS applications. This guide focuses on implementing HIG principles in SwiftUI for iOS 18.

## Design Principles

### Clarity
- Text is legible at every size
- Icons are precise and lucid
- Adornments are subtle and appropriate

### Deference
- Content fills the screen
- UI helps users understand and interact with content
- Minimal use of bezels, gradients, and drop shadows

### Depth
- Visual layers and realistic motion convey hierarchy
- Transitions provide a sense of depth
- Touch and discoverability heighten delight

## Typography

### System Fonts

```swift
// Dynamic Type support is automatic with system fonts
struct TypographyExamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Large Title")
                .font(.largeTitle)
            
            Text("Title 1")
                .font(.title)
            
            Text("Headline")
                .font(.headline)
            
            Text("Body Text")
                .font(.body)
            
            Text("Callout")
                .font(.callout)
            
            Text("Caption")
                .font(.caption)
        }
    }
}
```

### Custom Fonts with Dynamic Type

```swift
extension Font {
    static func customFont(_ name: String, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        Font.custom(name, size: size, relativeTo: textStyle)
    }
    
    // Army-themed custom fonts
    static let armyTitle = customFont("StencilStd", size: 34, relativeTo: .largeTitle)
    static let armyHeadline = customFont("StencilStd", size: 20, relativeTo: .headline)
    static let armyBody = customFont("Arial", size: 17, relativeTo: .body)
}

struct CustomTypography: View {
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        VStack {
            Text("RUCK TRACKER")
                .font(.armyTitle)
                .foregroundColor(.armyGreen)
            
            Text("Mission Statistics")
                .font(.armyHeadline)
        }
    }
}
```

## Color System

### Semantic Colors

```swift
extension Color {
    // Semantic colors adapt to light/dark mode
    static let primaryAction = Color("PrimaryAction")
    static let secondaryAction = Color("SecondaryAction")
    static let destructiveAction = Color("DestructiveAction")
    
    // System semantic colors
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let quaternaryText = Color(uiColor: .quaternaryLabel)
    
    // Background colors
    static let primaryBackground = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
}

// Define colors in Assets.xcassets with Any/Dark appearances
struct AdaptiveColorView: View {
    var body: some View {
        VStack {
            Text("Primary Text")
                .foregroundColor(.primaryText)
                .padding()
                .background(Color.primaryBackground)
            
            Text("Secondary Text")
                .foregroundColor(.secondaryText)
                .padding()
                .background(Color.secondaryBackground)
        }
    }
}
```

### Color Contrast Requirements

```swift
// Ensure WCAG AA compliance (4.5:1 for normal text, 3:1 for large text)
struct AccessibleColorPair {
    let foreground: Color
    let background: Color
    
    static let highContrast = AccessibleColorPair(
        foreground: Color(white: 0.1),
        background: Color(white: 0.95)
    )
    
    static let armyTheme = AccessibleColorPair(
        foreground: .white,
        background: Color(red: 0.29, green: 0.33, blue: 0.13) // Army green
    )
}
```

## Spacing and Layout

### Standard Spacing

```swift
enum Spacing {
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
}

struct SpacedLayout: View {
    var body: some View {
        VStack(spacing: Spacing.medium) {
            HeaderView()
                .padding(.horizontal, Spacing.medium)
            
            ContentSection()
                .padding(.vertical, Spacing.large)
            
            FooterView()
                .padding(.bottom, Spacing.xLarge)
        }
    }
}
```

### Safe Area and Margins

```swift
struct SafeAreaLayout: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                ForEach(items) { item in
                    ItemRow(item: item)
                        .padding(.horizontal)  // Respects safe area
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomBar()
        }
    }
}
```

## Touch Targets

### Minimum Touch Target Size

```swift
struct TouchTargetButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .frame(minWidth: 44, minHeight: 44)  // Apple's minimum
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(PressedButtonStyle())
    }
}

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

## Navigation Patterns

### NavigationStack (iOS 16+)

```swift
struct RuckNavigationView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            RuckListView()
                .navigationTitle("Ruck History")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: RuckSession.self) { session in
                    RuckDetailView(session: session)
                }
                .navigationDestination(for: Route.self) { route in
                    RouteDetailView(route: route)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add", systemImage: "plus") {
                            // Action
                        }
                    }
                }
        }
    }
}
```

### Tab Navigation

```swift
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "figure.walk")
                }
                .tag(0)
            
            RoutesView()
                .tabItem {
                    Label("Routes", systemImage: "map")
                }
                .tag(1)
            
            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
        }
        .tint(.armyGreen)  // Custom accent color
    }
}
```

## Modal Presentations

### Sheets and Full Screen Covers

```swift
struct ModalExamples: View {
    @State private var showingSheet = false
    @State private var showingFullScreen = false
    
    var body: some View {
        VStack(spacing: Spacing.large) {
            // Half-height sheet (iOS 16+)
            Button("Show Sheet") {
                showingSheet = true
            }
            .sheet(isPresented: $showingSheet) {
                RuckSetupView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(25)
            }
            
            // Full screen cover for immersive experiences
            Button("Start Ruck") {
                showingFullScreen = true
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                ActiveRuckView()
                    .preferredColorScheme(.dark)  // Force dark mode
            }
        }
    }
}
```

## Forms and Input

### Well-Designed Forms

```swift
struct RuckSetupForm: View {
    @State private var weight: Double = 35
    @State private var targetDistance: Double = 3
    @State private var selectedRoute: Route?
    @State private var useGPS = true
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Weight", systemImage: "scalemass")
                    Spacer()
                    Text("\(weight, specifier: "%.0f") lbs")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $weight, in: 0...100, step: 5)
                    .tint(.armyGreen)
            } header: {
                Text("Equipment")
            } footer: {
                Text("Include the weight of your rucksack and all gear")
            }
            
            Section("Route Planning") {
                Picker("Distance", selection: $targetDistance) {
                    ForEach([1, 3, 6, 12], id: \.self) { distance in
                        Text("\(distance) miles").tag(Double(distance))
                    }
                }
                
                NavigationLink {
                    RouteSelectionView(selectedRoute: $selectedRoute)
                } label: {
                    HStack {
                        Text("Select Route")
                        Spacer()
                        if let route = selectedRoute {
                            Text(route.name)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Toggle("Use GPS Tracking", isOn: $useGPS)
            }
        }
        .formStyle(.grouped)
    }
}
```

## SF Symbols

### Proper Symbol Usage

```swift
struct SymbolExamples: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            // Hierarchical rendering
            Label("Running", systemImage: "figure.run")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.armyGreen)
            
            // Multicolor symbols
            Label("Map Route", systemImage: "map.fill")
                .symbolRenderingMode(.multicolor)
            
            // Variable symbols
            Image(systemName: "speaker.wave.3.fill", 
                  variableValue: 0.7)
            
            // Symbol variants
            HStack {
                Image(systemName: "heart")
                Image(systemName: "heart.fill")
                Image(systemName: "heart.circle")
                Image(systemName: "heart.circle.fill")
            }
            .symbolVariant(.fill)  // Apply to all
        }
    }
}
```

## Haptic Feedback

### Appropriate Haptic Usage

```swift
struct HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

struct HapticButton: View {
    var body: some View {
        Button("Complete Ruck") {
            HapticFeedback.notification(.success)
            completeRuck()
        }
        
        Picker("Weight", selection: $weight) {
            // Options
        }
        .onChange(of: weight) { _, _ in
            HapticFeedback.selection()
        }
    }
}
```

## iOS 18 Specific Features

### Control Center Widgets

```swift
struct RuckControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.app.ruck-control"
        ) {
            ControlWidgetButton(action: QuickStartIntent()) {
                Label("Start Ruck", systemImage: "figure.walk")
            }
        }
        .displayName("Quick Ruck")
        .description("Start a ruck march quickly")
    }
}
```

### Interactive Widgets

```swift
struct RuckWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "RuckWidget",
            intent: ConfigurationIntent.self,
            provider: Provider()
        ) { entry in
            RuckWidgetView(entry: entry)
        }
        .configurationDisplayName("Ruck Tracker")
        .description("Track your ruck march progress")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()  // iOS 17+
    }
}
```

## Platform Adaptations

### iPhone vs iPad

```swift
struct AdaptiveLayout: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            // iPad layout
            NavigationSplitView {
                SidebarView()
            } content: {
                ContentListView()
            } detail: {
                DetailView()
            }
        } else {
            // iPhone layout
            NavigationStack {
                CompactView()
            }
        }
    }
}
```

## Best Practices Summary

### Do's
- ✅ Use semantic colors that adapt to dark mode
- ✅ Support Dynamic Type for all text
- ✅ Maintain 44pt minimum touch targets
- ✅ Use SF Symbols consistently
- ✅ Follow platform navigation patterns
- ✅ Provide haptic feedback for important actions
- ✅ Test with accessibility features enabled

### Don'ts
- ❌ Create custom UI that conflicts with system patterns
- ❌ Use hardcoded colors or sizes
- ❌ Ignore safe areas
- ❌ Override system gestures
- ❌ Use excessive animations
- ❌ Create inaccessible color combinations

## Testing for HIG Compliance

```swift
// Accessibility testing
struct AccessibilityTests {
    static func validateView<V: View>(_ view: V) {
        // Test with various size categories
        let sizeCategories: [ContentSizeCategory] = [
            .extraSmall, .small, .medium, .large,
            .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
            .accessibilityMedium, .accessibilityLarge,
            .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
            .accessibilityExtraExtraExtraLarge
        ]
        
        // Test with color schemes
        let colorSchemes: [ColorScheme] = [.light, .dark]
        
        // Test with reduced motion
        // Test with VoiceOver
        // Test color contrast ratios
    }
}
```

## Conclusion

Following Apple's Human Interface Guidelines ensures your SwiftUI app feels native, intuitive, and accessible. Key principles:

1. **Prioritize content** over chrome
2. **Use system components** when possible
3. **Support accessibility** from the start
4. **Test on real devices** with various settings
5. **Iterate based on user feedback**

The HIG evolves with each iOS release, so stay updated with Apple's latest guidance and WWDC sessions.