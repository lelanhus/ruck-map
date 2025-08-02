# Creating Adaptive Custom Color Palettes with SwiftUI Base Colors (iOS 18+)

## Foundation: Understanding SwiftUI's Adaptive Color System

SwiftUI's built-in colors automatically adapt to dark mode, accessibility settings, and different interface contexts. By using these as your foundation, you maintain all the semantic benefits while creating custom variations[1][2].

## Core Techniques for Custom Palette Creation

### 1. Color Mixing (iOS 18+)

The `mix(with:by:in:)` method is your primary tool for creating custom colors while maintaining adaptivity:

```swift
extension Color {
    // Brand palette based on system blue
    static let brandPrimary = Color.blue
    static let brandSecondary = Color.blue.mix(with: .purple, by: 0.3)
    static let brandAccent = Color.blue.mix(with: .cyan, by: 0.4)
    
    // Contextual variations
    static let brandLight = Color.blue.mix(with: .white, by: 0.2)
    static let brandDark = Color.blue.mix(with: .black, by: 0.15)
    static let brandMuted = Color.blue.mix(with: .gray, by: 0.4)
}
```

### 2. Hierarchical Color Levels

SwiftUI provides automatic hierarchical variations that adapt to the current environment:

```swift
struct BrandColorPalette {
    static let primary = Color.blue
    static let secondary = Color.blue.secondary      // Automatically dimmed
    static let tertiary = Color.blue.tertiary        // Further dimmed
    static let quaternary = Color.blue.quaternary    // Most subtle
}
```

### 3. Background-Aware Colors

Use background styles that automatically adapt to interface elevation:

```swift
extension Color {
    // Adaptive backgrounds that respond to interface level
    static let surfacePrimary = Color(uiColor: .systemBackground)
    static let surfaceSecondary = Color(uiColor: .secondarySystemBackground)
    static let surfaceTertiary = Color(uiColor: .tertiarySystemBackground)
    
    // Custom surfaces using hierarchical styles
    static let customSurface = Color.gray.secondary
    static let customElevated = Color.gray.tertiary
}
```

## Comprehensive Palette Creation Strategy

### Step 1: Define Your Base Colors

Start with semantic system colors as your foundation:

```swift
struct AppColorSystem {
    // Base semantic colors
    static let primary = Color.blue          // Main brand color
    static let secondary = Color.teal        // Supporting brand color
    static let accent = Color.orange         // Accent/action color
    static let success = Color.green         // Success states
    static let warning = Color.yellow        // Warning states
    static let error = Color.red             // Error states
}
```

### Step 2: Create Contextual Variations

Use mixing to create variations that maintain semantic meaning[3][4]:

```swift
extension AppColorSystem {
    // Light variations for backgrounds and subtle elements
    static let primaryLight = primary.mix(with: .white, by: 0.8)
    static let secondaryLight = secondary.mix(with: .white, by: 0.8)
    static let accentLight = accent.mix(with: .white, by: 0.8)
    
    // Dark variations for emphasis and borders
    static let primaryDark = primary.mix(with: .black, by: 0.2)
    static let secondaryDark = secondary.mix(with: .black, by: 0.2)
    static let accentDark = accent.mix(with: .black, by: 0.2)
    
    // Muted variations for disabled states
    static let primaryMuted = primary.mix(with: .gray, by: 0.5)
    static let secondaryMuted = secondary.mix(with: .gray, by: 0.5)
    static let accentMuted = accent.mix(with: .gray, by: 0.5)
}
```

### Step 3: Add Hierarchical Support

Leverage SwiftUI's hierarchical system for automatic adaptation[5][6]:

```swift
extension AppColorSystem {
    // Hierarchical text colors
    static let textPrimary = primary
    static let textSecondary = primary.secondary
    static let textTertiary = primary.tertiary
    
    // Hierarchical backgrounds
    static let backgroundPrimary = Color(uiColor: .systemBackground)
    static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    static let backgroundTertiary = Color(uiColor: .tertiarySystemBackground)
}
```

## Complete Implementation Example

Here's a comprehensive example showing all techniques combined:

```swift
struct AdaptiveColorPalette {
    // MARK: - Base Brand Colors
    static let brandBlue = Color.blue
    static let brandTeal = Color.teal
    static let brandOrange = Color.orange
    
    // MARK: - Mixed Brand Variations
    static let brandPurple = brandBlue.mix(with: .purple, by: 0.4)
    static let brandCyan = brandTeal.mix(with: .cyan, by: 0.3)
    static let brandRed = brandOrange.mix(with: .red, by: 0.2)
    
    // MARK: - Contextual Variations
    struct Primary {
        static let base = brandBlue
        static let light = base.mix(with: .white, by: 0.3)
        static let dark = base.mix(with: .black, by: 0.15)
        static let muted = base.mix(with: .gray, by: 0.4)
        
        // Hierarchical variants
        static let secondary = base.secondary
        static let tertiary = base.tertiary
        static let quaternary = base.quaternary
    }
    
    struct Surface {
        static let primary = Color(uiColor: .systemBackground)
        static let secondary = Color(uiColor: .secondarySystemBackground)
        static let tertiary = Color(uiColor: .tertiarySystemBackground)
        
        // Custom surface colors
        static let brandSurface = brandBlue.mix(with: .white, by: 0.95)
        static let accentSurface = brandOrange.mix(with: .white, by: 0.9)
    }
    
    struct Interactive {
        static let primary = brandBlue
        static let secondary = brandTeal
        static let disabled = brandBlue.mix(with: .gray, by: 0.6)
        
        // State variations
        static let hover = brandBlue.mix(with: .white, by: 0.1)
        static let pressed = brandBlue.mix(with: .black, by: 0.1)
    }
}
```

## Usage in Views

Here's how to use your adaptive palette in practice:

```swift
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Primary content with hierarchical text
            VStack {
                Text("Primary Title")
                    .foregroundStyle(AdaptiveColorPalette.Primary.base)
                    .font(.title)
                
                Text("Secondary Description")
                    .foregroundStyle(AdaptiveColorPalette.Primary.secondary)
                    .font(.body)
                
                Text("Tertiary Details")
                    .foregroundStyle(AdaptiveColorPalette.Primary.tertiary)
                    .font(.caption)
            }
            .padding()
            .background(AdaptiveColorPalette.Surface.secondary)
            .cornerRadius(12)
            
            // Interactive elements
            HStack {
                Button("Primary Action") {
                    // Action
                }
                .foregroundStyle(.white)
                .padding()
                .background(AdaptiveColorPalette.Interactive.primary)
                .cornerRadius(8)
                
                Button("Secondary Action") {
                    // Action
                }
                .foregroundStyle(AdaptiveColorPalette.Interactive.secondary)
                .padding()
                .background(AdaptiveColorPalette.Interactive.secondary.mix(with: .white, by: 0.8))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(AdaptiveColorPalette.Surface.primary)
    }
}
```

## Dynamic Color Generation

For runtime palette generation, create a system that maintains adaptivity:

```swift
struct DynamicPalette {
    let baseColor: Color
    
    var light: Color { baseColor.mix(with: .white, by: 0.3) }
    var dark: Color { baseColor.mix(with: .black, by: 0.2) }
    var muted: Color { baseColor.mix(with: .gray, by: 0.4) }
    var accent: Color { baseColor.mix(with: .yellow, by: 0.1) }
    
    // Hierarchical variants
    var secondary: Color { baseColor.secondary }
    var tertiary: Color { baseColor.tertiary }
    
    // Complementary colors
    var complementary: Color { baseColor.mix(with: complementaryBase, by: 0.5) }
    
    private var complementaryBase: Color {
        // Simple complementary logic - in practice, use proper color theory
        switch baseColor {
        case .blue: return .orange
        case .red: return .green
        case .green: return .red
        default: return .purple
        }
    }
}

// Usage
let dynamicBlue = DynamicPalette(baseColor: .blue)
let dynamicGreen = DynamicPalette(baseColor: .green)
```

## Key Benefits of This Approach

1. **Automatic Dark Mode Support**: All variations adapt seamlessly to light/dark mode[1][2]
2. **Accessibility Compliance**: Maintains proper contrast ratios and responds to accessibility settings[7][8]
3. **Context Awareness**: Colors adapt to interface elevation and semantic meaning[5][9]
4. **Animation Support**: All color transitions are smoothly animatable[3]
5. **Consistency**: Maintains visual hierarchy and design system coherence[10][6]
6. **Future-Proof**: Adapts to system updates and new accessibility features automatically

This approach gives you complete creative control while maintaining all the adaptive benefits of SwiftUI's color system, ensuring your custom palette works beautifully across all user preferences and system states.

Sources
[1] Defining dynamic colors in Swift - Swift by Sundell https://www.swiftbysundell.com/articles/defining-dynamic-colors-in-swift
[2] Semantic Colors and Styles - Chris Eidhof https://chris.eidhof.nl/post/semantic-colors/
[3] Color mixing in SwiftUI | Swift with Majid https://swiftwithmajid.com/2025/01/21/color-mixing-in-swiftui/
[4] Mixing colors in SwiftUI and Xcode 16 - Donny Wals https://www.donnywals.com/mixing-colors-in-swiftui-and-xcode-16/
[5] Hierarchical background styles in SwiftUI - Nil Coalescing https://nilcoalescing.com/blog/HierarchicalBackgroundStyles
[6] How to Correctly use .secondary Hierarchy in SwiftUI | SwiftyLion https://swiftylion.com/articles/how-to-correctly-use-secondary-hierarchy-in-swiftui
[7] SwiftUI view modifers and dark mode - Codakuma https://codakuma.com/view-modifiers-dark-mode/
[8] How to support dark mode in SwiftUI programmatically https://tanaschita.com/supporting-dark-mode-programmatically/
[9] The Power of ShapeStyle for Colour theming in SwiftUI - Teabyte https://alexanderweiss.dev/blog/2024-12-27-the-power-of-shapestyle-for-colour-theming-in-swiftui
[10] Stop Creating Custom Colors in SwiftUI - YouTube https://www.youtube.com/watch?v=oJDu0dKa0PU&vl=en
[11] SwiftUI Color Mixing Deep Dive - YouTube https://www.youtube.com/watch?v=HaoEhTLDfdI
[12] SwiftUI Colors Are TRICKY... Here's What You NEED to Know! https://www.youtube.com/watch?v=i6e8JB0KhXU
[13] SwiftUI Colors – Exploring Overlooked Features - SerialCoder.dev https://serialcoder.dev/text-tutorials/swiftui/swiftui-colors-exploring-overlooked-features/
[14] Mixing Colors in SwiftUI for iOS 18 - YouTube https://www.youtube.com/watch?v=jXqqL0Ygd5k
[15] Ways to customize text color in SwiftUI - Nil Coalescing https://nilcoalescing.com/blog/ForegroundColorStyleAndTintInSwiftUI
[16] Change background color when dark mode turns on in SwiftUI https://stackoverflow.com/questions/59694589/change-background-color-when-dark-mode-turns-on-in-swiftui
[17] Exploring SwiftUI: Animating Mesh Gradient with Colors in iOS 18 https://www.rudrank.com/exploring-swiftui-animating-mesh-gradient-with-colors-in-ios-18/
[18] SF Symbols Hierarchical, Palette, and Multicolor rendering mode ... https://stackoverflow.com/questions/69304679/sf-symbols-hierarchical-palette-and-multicolor-rendering-mode-colors
[19] SwiftUI - Accessing iOS 13's semantic colors - Stack Overflow https://stackoverflow.com/questions/56589958/swiftui-accessing-ios-13s-semantic-colors
[20] What's New in SwiftUI for iOS 18 - AppCoda https://www.appcoda.com/swiftui-ios-18/
[21] Customizing the appearance of symbol images in SwiftUI https://nilcoalescing.com/blog/CustomizingTheAppearanceOfSymbolImagesInSwiftUI
[22] Supporting Dark Mode in your interface - Apple Developer https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface
[23] Blending colors dynamically with the mix modifier - Create with Swift https://www.createwithswift.com/blending-colors-dynamically-with-mix-modifier/
[24] Confusion about hierarchical colors : r/SwiftUI - Reddit https://www.reddit.com/r/SwiftUI/comments/1efoz4g/confusion_about_hierarchical_colors/
[25] Configuring SwiftUI views - Swift by Sundell https://www.swiftbysundell.com/articles/configuring-swiftui-views
[26] Dynamic colors in SwiftUI - Tanaschita.com https://tanaschita.com/swiftui-dynamic-colors/
[27] What are the .primary and .secondary colors in SwiftUI? https://stackoverflow.com/questions/56466128/what-are-the-primary-and-secondary-colors-in-swiftui
[28] iOS Semantic UI: Dark Mode, Dynamic Type, and SF Symbols - GitHub https://github.com/cocoacontrols/SemanticUI
[29] Standard colors | Apple Developer Documentation https://developer.apple.com/documentation/uikit/standard-colors
[30] SwiftUI List: Deep Dive - DevTechie https://www.devtechie.com/community/public/posts/149888-swiftui-list-deep-dive
[31] System colors in SwiftUI : r/swift - Reddit https://www.reddit.com/r/swift/comments/18or5w7/system_colors_in_swiftui/
[32] systemBlue | Apple Developer Documentation https://developer.apple.com/documentation/uikit/uicolor/systemblue
[33] Material | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/material
[34] Color | Apple Developer Documentation https://developer.apple.com/design/human-interface-guidelines/color
[35] A simple extension to SwiftUI Color that bridges over ... - GitHub Gist https://gist.github.com/HiddenJester/1a601bc5256dccaa0022bcd973a76c8b
[36] Create Consistent SwiftUI Designs Written by Team Kodeco https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/11-create-consistent-swiftui-designs
[37] Dark color cheat sheet - Sarunw https://sarunw.com/posts/dark-color-cheat-sheet/
[38] A Color convenience extension to make adaptable UIColors more ... https://gist.github.com/bc168d2988610c91cf5bbc23ae422b1e
