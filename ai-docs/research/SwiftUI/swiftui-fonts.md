# Making SwiftUI's Default Font Feel Custom: Typography Best Practices

SwiftUI's default San Francisco (SF) font family offers remarkable versatility and can create custom-feeling designs without requiring external fonts. By leveraging built-in font modifiers and following typography best practices, you can achieve sophisticated, accessible designs while maintaining all the benefits of system fonts.

## Core Font Styling Options

### Font Weight Variations

SwiftUI provides comprehensive font weight options from ultra-thin to black[1][2]:

```swift
Text("Ultra Light")
    .fontWeight(.ultraLight)

Text("Light")
    .fontWeight(.light)

Text("Regular")
    .fontWeight(.regular)

Text("Medium")
    .fontWeight(.medium)

Text("Bold")
    .fontWeight(.bold)

Text("Heavy")
    .fontWeight(.heavy)

Text("Black")
    .fontWeight(.black)
```

### Font Width Modifiers

iOS 16 introduced font width options that dramatically change text appearance[3]:

```swift
Text("Expanded Text")
    .font(.title.width(.expanded))

Text("Condensed Text")
    .font(.body.width(.condensed))

Text("Compressed Text")
    .font(.caption.width(.compressed))
```

These width variations are particularly useful for space efficiency and creating distinctive visual hierarchy without changing font families[4].

### Font Design Styles

SwiftUI offers four distinct design variations[2][4]:

- **Default**: Standard SF font
- **Serif**: New York font family for more traditional feel
- **Rounded**: SF Rounded for friendly, approachable designs
- **Monospaced**: SF Mono for code or technical content

```swift
Text("Default Design")
    .font(.title.design(.default))

Text("Serif Design")
    .font(.title.design(.serif))

Text("Rounded Design")
    .font(.title.design(.rounded))

Text("Monospaced Design")
    .font(.title.design(.monospaced))
```

## Typography Hierarchy and Spacing

### Establishing Visual Hierarchy

Create clear information hierarchy using built-in text styles combined with hierarchical foreground colors[5]:

```swift
VStack(alignment: .leading, spacing: 16) {
    Text("Primary Heading")
        .font(.largeTitle)
        .fontWeight(.bold)
    
    Text("Secondary Information")
        .font(.title2)
        .foregroundStyle(.secondary)
    
    Text("Body Content")
        .font(.body)
        .foregroundStyle(.primary)
    
    Text("Supporting Details")
        .font(.caption)
        .foregroundStyle(.tertiary)
}
```

### Spacing and Padding Guidelines

Proper spacing is crucial for readable typography[6][7]:

**Line Spacing**: Use `.lineSpacing()` to adjust space between lines:
```swift
Text("Multi-line content with custom line spacing")
    .lineSpacing(4) // Adds 4 points between lines
```

**Padding Best Practices**[6]:
- Use 16-20 points for content padding from screen edges
- Apply 8-12 points between related elements
- Use 20-32 points between distinct content sections

```swift
VStack(spacing: 20) {
    Text("Title")
        .font(.title)
        .padding(.bottom, 8)
    
    Text("Body content with proper spacing")
        .padding(.horizontal, 16)
}
.padding(.vertical, 20)
```

## Advanced Typography Techniques

### Character and Word Spacing

Fine-tune character spacing with tracking[8]:

```swift
Text("Spaced Out Text")
    .tracking(2) // Increases character spacing by 2 points

Text("Tight Text")
    .tracking(-0.5) // Decreases character spacing
```

### Leading (Line Height) Control

Control line height with the `.leading()` modifier[9][10]:

```swift
Text("Text with tight leading")
    .font(.body.leading(.tight))

Text("Text with loose leading")
    .font(.body.leading(.loose))
```

### Creating Custom Font Combinations

Combine multiple modifiers for unique effects[9]:

```swift
Text("Custom Styled Heading")
    .font(
        .largeTitle
        .bold()
        .width(.expanded)
        .design(.rounded)
    )
    .tracking(1)
    .foregroundStyle(.primary)
```

## Accessibility and Dynamic Type

### Supporting Dynamic Type

Always use system text styles to maintain Dynamic Type support[11][12]:

```swift
@Environment(\.sizeCategory) var sizeCategory

Text("Responsive Text")
    .font(.body)
    .lineLimit(sizeCategory >= .accessibilityMedium ? nil : 3)
```

### Minimum Font Sizes

Follow accessibility guidelines for minimum readable sizes[13]:
- Body text: minimum 16pt
- Recommended body range: 16-18pt
- Never go below 12pt for any readable content

### Using Scaled Metrics

Scale non-text elements with font size changes[14]:

```swift
@ScaledMetric(relativeTo: .body) private var iconSize = 20

HStack {
    Image(systemName: "star")
        .font(.system(size: iconSize))
    Text("Scaled Content")
}
```

## Design System Implementation

### Creating Consistent Typography

Establish a typography system using extensions[15]:

```swift
extension Font {
    static let customHeadline = Font.system(.title, design: .rounded, weight: .bold)
    static let customBody = Font.system(.body, design: .default, weight: .regular)
    static let customCaption = Font.system(.caption, design: .default, weight: .medium)
}

// Usage
Text("Consistent Heading")
    .font(.customHeadline)
```

### Environmental Font Settings

Set default fonts app-wide using environment[16]:

```swift
WindowGroup {
    ContentView()
        .environment(\.font, .system(.body, design: .rounded))
}
```

## Best Practices Summary

### Typography Rules of Thumb

1. **Hierarchy**: Use size and weight changes to create clear information hierarchy
2. **Contrast**: Maintain sufficient contrast ratios (4.5:1 minimum for normal text)
3. **Spacing**: Apply consistent spacing patterns throughout your app
4. **Line Length**: Keep lines between 45-75 characters for optimal readability
5. **Leading**: Ensure adequate line spacing (typically 120-150% of font size)

### Spacing Guidelines[6][13]

| Element | Recommended Spacing |
|---------|-------------------|
| Content padding | 16-20pt |
| Section spacing | 24-32pt |
| Element spacing | 8-12pt |
| Line spacing | 4-8pt additional |
| Minimum touch targets | 44x44pt |

### Performance Considerations

- System fonts render faster than custom fonts
- Dynamic Type works automatically with system fonts
- Built-in fonts support all accessibility features
- No additional memory overhead for font loading

By mastering these SwiftUI font customization techniques, you can create distinctive, professional-looking typography that feels custom while maintaining all the benefits of system fonts including accessibility, performance, and automatic adaptation to user preferences[4].

Sources
[1] How to use custom font weight value in SwiftUI? - Stack Overflow https://stackoverflow.com/questions/77326871/how-to-use-custom-font-weight-value-in-swiftui
[2] How to style SwiftUI text Font - Sarunw https://sarunw.com/posts/swiftui-text-font/
[3] How to change SwiftUI Font Width - Sarunw https://sarunw.com/posts/swiftui-font-width/
[4] Why SwiftUI's Built-In Font is OP 🔥 - YouTube https://www.youtube.com/watch?v=e4s37VcWCj0
[5] How to Correctly use .secondary Hierarchy in SwiftUI | SwiftyLion https://swiftylion.com/articles/how-to-correctly-use-secondary-hierarchy-in-swiftui
[6] Adding Padding & Spacing in SwiftUI - Kodeco https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/8-adding-padding-spacing-in-swiftui
[7] How To Use SwiftUI Spacing And Padding - YouTube https://www.youtube.com/watch?v=ghmG1AGcjQY
[8] SwiftUI .tracking() - ViewModifier - Codecademy https://www.codecademy.com/resources/docs/swiftui/viewmodifier/tracking
[9] Font modifiers in SwiftUI - Nil Coalescing https://nilcoalescing.com/blog/FontModifiersInSwiftUI
[10] leading(_:) | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/font/leading(_:)
[11] SwiftUI Accessibility: Dynamic Type - Mobile A11y https://mobilea11y.com/guides/swiftui/swiftui-dynamic-type/
[12] Responding to Dynamic Type in SwiftUI for Accessibility - Kodeco https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/1-responding-to-dynamic-type-in-swiftui-for-accessibility
[13] Ensure Visual Accessibility: Using Typography - Create with Swift https://www.createwithswift.com/ensure-visual-accessibility-using-typography/
[14] Dynamic Type - SwiftUI Field Guide https://www.swiftuifieldguide.com/layout/dynamic-type/
[15] Exploring SwiftUI: Typography System - rryam https://rryam.com/swiftui-typography-system
[16] How to set the default font of SwiftUI.Text? - Stack Overflow https://stackoverflow.com/questions/75984664/how-to-set-the-default-font-of-swiftui-text
[17] SwiftUI Font and Texts - swiftyplace https://www.swiftyplace.com/blog/swiftui-font-and-texts
[18] Using Font Features in SwiftUI - Swift Forums https://forums.swift.org/t/using-font-features-in-swiftui/36849
[19] weight(_:) | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/font/weight(_:)
[20] SwiftUI under the Hood: Fonts - Moving Parts https://movingparts.io/fonts-in-swiftui
[21] Font.Weight | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/font/weight
[22] Whats the best way to create a common color/font theme for ... - Reddit https://www.reddit.com/r/SwiftUI/comments/1h89d8p/whats_the_best_way_to_create_a_common_colorfont/
[23] Overwrite default font : r/SwiftUI - Reddit https://www.reddit.com/r/SwiftUI/comments/sbvwmw/overwrite_default_font/
[24] Typography | Apple Developer Documentation https://developer.apple.com/design/human-interface-guidelines/typography
[25] Applying custom fonts to text | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text/
[26] Font | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/font
[27] Fix line spacing in custom font in SwiftUI - Stack Overflow https://stackoverflow.com/questions/68229689/fix-line-spacing-in-custom-font-in-swiftui
[28] Accessibility - SwiftUI - Codecademy https://www.codecademy.com/resources/docs/swiftui/accessibility
[29] Text spacing in SwiftUI - Appt.org https://appt.org/en/docs/swiftui/samples/text-spacing
[30] Adapting images and symbols to Dynamic Type sizes in SwiftUI https://nilcoalescing.com/blog/AdaptingImagesAndSymbolsToDynamicTypeSizesInSwiftUI
[31] Specifying the view hierarchy of an app using a scene — SwiftUI ... https://developer.apple.com/tutorials/swiftui-concepts/specifying-the-view-hierarchy-of-an-app-using-a-scene
[32] padding(_:_:) | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/view/padding(_:_:)
[33] How to Use Hierarchical Foreground Styles in SwiftUI for Text https://www.youtube.com/shorts/7ZDgpeZiXCc
[34] Understanding typography in visionOS - Create with Swift https://www.createwithswift.com/understanding-typography-in-visionos/
[35] iOS 13: How can I tweak the leading / descend / line height of a ... https://stackoverflow.com/questions/63622822/ios-13-how-can-i-tweak-the-leading-descend-line-height-of-a-custom-font-in
[36] How to align text center/leading/trailing in SwiftUI - Sarunw https://sarunw.com/posts/how-to-align-text-in-swiftui/
[37] Reduce line height to actual characters used in SwiftUI Text element https://stackoverflow.com/questions/77384482/reduce-line-height-to-actual-characters-used-in-swiftui-text-element/77384590
[38] Change default system font in SwiftUI - Stack Overflow https://stackoverflow.com/questions/58842643/change-default-system-font-in-swiftui
[39] SwiftUI Text: line height of 1st - Apple Developer Forums https://forums.developer.apple.com/forums/thread/650982
[40] Mastering SwiftUI's Text View: A Deep Dive into Modifiers for Font ... https://www.boltuix.com/2021/02/mastering-swiftuis-text-view-deep-dive.html
[41] How to get height of font(.body) and font(.subtitle)? - SwiftUI - Reddit https://www.reddit.com/r/SwiftUI/comments/hszw1g/how_to_get_height_of_fontbody_and_fontsubtitle/
[42] The magic of fixed size modifier in SwiftUI - Swift with Majid https://swiftwithmajid.com/2020/04/29/the-magic-of-fixed-size-modifier-in-swiftui/
[43] Font.Design | Apple Developer Documentation https://developer.apple.com/documentation/swiftui/font/design
[44] Auto Resizable Text Size In SwiftUI | Malauch's Swift Notes https://malauch.com/posts/auto-resizable-text-size-in-swiftui/
