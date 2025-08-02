# SwiftUI Animation and Gesture Handling

## Overview

Animations and gestures are essential for creating fluid, responsive user experiences. This guide covers SwiftUI animation techniques, gesture recognizers, and best practices for iOS 18+.

## Animation Fundamentals

### Basic Animations

```swift
struct BasicAnimations: View {
    @State private var isExpanded = false
    @State private var rotationAngle = 0.0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 40) {
            // Implicit Animation
            Circle()
                .fill(Color.armyGreen)
                .frame(width: isExpanded ? 200 : 100, height: isExpanded ? 200 : 100)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isExpanded)
                .onTapGesture {
                    isExpanded.toggle()
                }
            
            // Explicit Animation
            Image(systemName: "figure.walk")
                .font(.system(size: 60))
                .rotationEffect(.degrees(rotationAngle))
                .scaleEffect(scale)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                        rotationAngle += 360
                        scale = scale == 1.0 ? 1.2 : 1.0
                    }
                }
        }
    }
}
```

### Animation Types

```swift
struct AnimationTypes: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Linear Animation
            AnimatedRectangle(title: "Linear", offset: offset)
                .animation(.linear(duration: 1.0), value: offset)
            
            // Ease In/Out
            AnimatedRectangle(title: "Ease In Out", offset: offset)
                .animation(.easeInOut(duration: 1.0), value: offset)
            
            // Spring Animation
            AnimatedRectangle(title: "Spring", offset: offset)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: offset)
            
            // Interactive Spring
            AnimatedRectangle(title: "Interactive Spring", offset: offset)
                .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.2), value: offset)
            
            // Custom Timing Curve
            AnimatedRectangle(title: "Custom", offset: offset)
                .animation(.timingCurve(0.2, 0.0, 0.2, 1.0, duration: 1.0), value: offset)
            
            Button("Animate") {
                offset = offset == 0 ? 200 : 0
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct AnimatedRectangle: View {
    let title: String
    let offset: CGFloat
    
    var body: some View {
        HStack {
            Text(title)
                .frame(width: 120, alignment: .leading)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.armyGreen)
                .frame(width: 50, height: 30)
                .offset(x: offset)
            
            Spacer()
        }
    }
}
```

## Advanced Animation Techniques

### Matched Geometry Effect

```swift
struct MatchedGeometryExample: View {
    @Namespace private var animation
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            if !isExpanded {
                // Collapsed State
                HStack {
                    RuckSummaryCard()
                        .matchedGeometryEffect(id: "ruckCard", in: animation)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isExpanded = true
                            }
                        }
                }
                .frame(height: 100)
            } else {
                // Expanded State
                VStack {
                    RuckDetailCard()
                        .matchedGeometryEffect(id: "ruckCard", in: animation)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
}
```

### Phase Animator

```swift
struct PhaseAnimatorExample: View {
    @State private var trigger = false
    
    var body: some View {
        Image(systemName: "figure.walk")
            .font(.system(size: 100))
            .phaseAnimator([false, true], trigger: trigger) { view, phase in
                view
                    .scaleEffect(phase ? 1.2 : 1.0)
                    .foregroundStyle(phase ? Color.armyGreen : Color.gray)
            } animation: { phase in
                switch phase {
                case true:
                    .spring(response: 0.3, dampingFraction: 0.5)
                case false:
                    .easeOut(duration: 0.3)
                }
            }
            .onTapGesture {
                trigger.toggle()
            }
    }
}
```

### Keyframe Animation

```swift
struct KeyframeAnimationExample: View {
    @State private var startAnimation = false
    
    var body: some View {
        Image(systemName: "figure.walk")
            .font(.system(size: 80))
            .keyframeAnimator(initialValue: AnimationProperties(), trigger: startAnimation) { view, value in
                view
                    .rotationEffect(.degrees(value.rotation))
                    .scaleEffect(value.scale)
                    .offset(y: value.yOffset)
            } keyframes: { _ in
                KeyframeTrack(\.rotation) {
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(-10, duration: 0.2)
                    CubicKeyframe(10, duration: 0.2)
                    CubicKeyframe(-10, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                }
                
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.0, duration: 0.2)
                    SpringKeyframe(1.2, duration: 0.3)
                    SpringKeyframe(1.0, duration: 0.3)
                }
                
                KeyframeTrack(\.yOffset) {
                    LinearKeyframe(0, duration: 0.2)
                    CubicKeyframe(-20, duration: 0.3)
                    CubicKeyframe(0, duration: 0.3)
                }
            }
            .onTapGesture {
                startAnimation.toggle()
            }
    }
}

struct AnimationProperties {
    var rotation: Double = 0
    var scale: CGFloat = 1.0
    var yOffset: CGFloat = 0
}
```

## Gesture Recognition

### Basic Gestures

```swift
struct BasicGestures: View {
    @State private var tapCount = 0
    @State private var longPressDetected = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        VStack(spacing: 40) {
            // Tap Gesture
            Text("Taps: \(tapCount)")
                .font(.largeTitle)
                .padding()
                .background(Color.armyGreen.opacity(0.2))
                .cornerRadius(12)
                .onTapGesture(count: 2) {
                    tapCount += 2
                }
                .onTapGesture {
                    tapCount += 1
                }
            
            // Long Press Gesture
            Circle()
                .fill(longPressDetected ? Color.armyGreen : Color.gray)
                .frame(width: 100, height: 100)
                .scaleEffect(longPressDetected ? 1.2 : 1.0)
                .onLongPressGesture(minimumDuration: 1.0) {
                    withAnimation(.spring()) {
                        longPressDetected.toggle()
                    }
                }
            
            // Drag Gesture
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.armyGreen)
                .frame(width: 150, height: 150)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                )
        }
        .padding()
    }
}
```

### Advanced Gesture Handling

```swift
struct AdvancedGestures: View {
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentRotation: Angle = .zero
    @State private var finalRotation: Angle = .zero
    @State private var currentOffset = CGSize.zero
    @State private var finalOffset = CGSize.zero
    
    var body: some View {
        Image(systemName: "map")
            .font(.system(size: 200))
            .foregroundColor(.armyGreen)
            .scaleEffect(currentScale * finalScale)
            .rotationEffect(currentRotation + finalRotation)
            .offset(currentOffset)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentScale = value
                        }
                        .onEnded { value in
                            finalScale *= value
                            currentScale = 1.0
                        },
                    RotationGesture()
                        .onChanged { value in
                            currentRotation = value
                        }
                        .onEnded { value in
                            finalRotation += value
                            currentRotation = .zero
                        }
                )
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        currentOffset = CGSize(
                            width: finalOffset.width + value.translation.width,
                            height: finalOffset.height + value.translation.height
                        )
                    }
                    .onEnded { value in
                        finalOffset = currentOffset
                    }
            )
            .onTapGesture(count: 2) {
                // Reset transforms
                withAnimation(.spring()) {
                    finalScale = 1.0
                    currentScale = 1.0
                    finalRotation = .zero
                    currentRotation = .zero
                    finalOffset = .zero
                    currentOffset = .zero
                }
            }
    }
}
```

### Custom Gesture Combinations

```swift
struct SwipeToDelete: View {
    @State private var offset: CGFloat = 0
    @State private var isDeleted = false
    
    var body: some View {
        if !isDeleted {
            HStack {
                Text("Swipe to Delete")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.armyGreen.opacity(0.2))
                    .cornerRadius(12)
                
                // Delete button revealed by swipe
                Button(action: delete) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .frame(width: 60)
                }
                .frame(width: max(0, -offset))
                .opacity(Double(-offset / 60))
                .background(Color.red)
            }
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if -value.translation.width > 60 {
                            delete()
                        } else {
                            withAnimation(.spring()) {
                                offset = 0
                            }
                        }
                    }
            )
        }
    }
    
    private func delete() {
        withAnimation(.easeOut(duration: 0.3)) {
            offset = -UIScreen.main.bounds.width
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isDeleted = true
        }
    }
}
```

## Interactive Animations

### Gesture-Driven Animation

```swift
struct InteractiveCardStack: View {
    @State private var cards = (0..<5).map { CardData(id: $0) }
    
    var body: some View {
        ZStack {
            ForEach(cards.indices, id: \.self) { index in
                CardView(card: cards[index])
                    .offset(y: CGFloat(index) * 10)
                    .scaleEffect(1.0 - CGFloat(index) * 0.05)
                    .zIndex(Double(cards.count - index))
                    .allowsHitTesting(index == 0)
                    .onDragEnded { _ in
                        removeCard(at: index)
                    }
            }
        }
    }
    
    private func removeCard(at index: Int) {
        withAnimation(.spring()) {
            cards.remove(at: index)
        }
    }
}

struct CardView: View {
    let card: CardData
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.armyGreen)
            .frame(width: 300, height: 200)
            .overlay(
                Text("Card \(card.id)")
                    .foregroundColor(.white)
                    .font(.largeTitle)
            )
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation
                        rotation = Double(value.translation.width / 20)
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > 150 {
                            // Swipe away
                            offset = CGSize(
                                width: value.translation.width > 0 ? 500 : -500,
                                height: value.translation.height
                            )
                        } else {
                            // Snap back
                            withAnimation(.spring()) {
                                offset = .zero
                                rotation = 0
                            }
                        }
                    }
            )
    }
}

struct CardData: Identifiable {
    let id: Int
}
```

### Spring Animation with Gesture Velocity

```swift
struct VelocityBasedAnimation: View {
    @State private var position = CGPoint(x: 150, y: 150)
    @State private var gestureVelocity = CGSize.zero
    
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.armyGreen)
                .frame(width: 80, height: 80)
                .position(position)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            position = value.location
                        }
                        .onEnded { value in
                            gestureVelocity = value.velocity
                            
                            // Calculate end position based on velocity
                            let projectedEndpoint = CGPoint(
                                x: position.x + gestureVelocity.width * 0.3,
                                y: position.y + gestureVelocity.height * 0.3
                            )
                            
                            // Constrain to bounds
                            let finalPosition = CGPoint(
                                x: max(40, min(geometry.size.width - 40, projectedEndpoint.x)),
                                y: max(40, min(geometry.size.height - 40, projectedEndpoint.y))
                            )
                            
                            // Animate with spring based on velocity
                            let distance = sqrt(pow(gestureVelocity.width, 2) + pow(gestureVelocity.height, 2))
                            let springResponse = min(0.5, distance / 1000)
                            
                            withAnimation(.spring(response: springResponse, dampingFraction: 0.7)) {
                                position = finalPosition
                            }
                        }
                )
        }
    }
}

extension DragGesture.Value {
    var velocity: CGSize {
        CGSize(
            width: predictedEndTranslation.width - translation.width,
            height: predictedEndTranslation.height - translation.height
        )
    }
}
```

## Performance Optimization

### Efficient Animation Patterns

```swift
struct EfficientAnimations: View {
    @State private var items = (0..<50).map { Item(id: $0) }
    @State private var animateAll = false
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) {
                ForEach(items) { item in
                    ItemView(item: item, shouldAnimate: animateAll)
                        .onAppear {
                            // Stagger animations for performance
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(item.id) * 0.05) {
                                withAnimation(.spring()) {
                                    // Animate individual item
                                }
                            }
                        }
                }
            }
            .padding()
        }
    }
}

struct ItemView: View {
    let item: Item
    let shouldAnimate: Bool
    @State private var isVisible = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.armyGreen)
            .frame(height: 80)
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                if !isVisible {
                    withAnimation(.spring().delay(Double(item.id) * 0.02)) {
                        isVisible = true
                    }
                }
            }
    }
}

struct Item: Identifiable {
    let id: Int
}
```

### Animation Debugging

```swift
struct AnimationDebugger: View {
    @State private var animationProgress: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Visual representation of animation
            Circle()
                .fill(Color.armyGreen)
                .frame(width: 100, height: 100)
                .scaleEffect(1.0 + animationProgress)
                .opacity(1.0 - animationProgress * 0.5)
            
            // Debug information
            VStack(alignment: .leading) {
                Text("Progress: \(animationProgress, specifier: "%.2f")")
                Text("Is Animating: \(isAnimating ? "Yes" : "No")")
            }
            .font(.system(.body, design: .monospaced))
            
            // Manual animation control
            Slider(value: $animationProgress, in: 0...1)
                .disabled(isAnimating)
            
            Button(isAnimating ? "Stop" : "Animate") {
                if isAnimating {
                    isAnimating = false
                    animationProgress = 0
                } else {
                    isAnimating = true
                    withAnimation(.linear(duration: 2.0)) {
                        animationProgress = 1.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isAnimating = false
                        animationProgress = 0
                    }
                }
            }
        }
        .padding()
    }
}
```

## Best Practices

### 1. Animation Performance

```swift
// ✅ Good: Animate transforms instead of layout
struct GoodAnimation: View {
    @State private var isExpanded = false
    
    var body: some View {
        Circle()
            .fill(Color.armyGreen)
            .frame(width: 100, height: 100)
            .scaleEffect(isExpanded ? 2 : 1)  // Transform animation
            .animation(.spring(), value: isExpanded)
    }
}

// ❌ Bad: Animating frame changes
struct BadAnimation: View {
    @State private var isExpanded = false
    
    var body: some View {
        Circle()
            .fill(Color.armyGreen)
            .frame(width: isExpanded ? 200 : 100, height: isExpanded ? 200 : 100)  // Layout animation
            .animation(.spring(), value: isExpanded)
    }
}
```

### 2. Gesture Conflict Resolution

```swift
struct GestureConflictResolution: View {
    @State private var parentOffset = CGSize.zero
    @State private var childScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Parent with drag gesture
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 300, height: 300)
                .offset(parentOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            parentOffset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                parentOffset = .zero
                            }
                        }
                )
            
            // Child with tap gesture (use simultaneousGesture to avoid conflicts)
            Circle()
                .fill(Color.armyGreen)
                .frame(width: 100, height: 100)
                .scaleEffect(childScale)
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            withAnimation(.spring()) {
                                childScale = childScale == 1.0 ? 1.5 : 1.0
                            }
                        }
                )
        }
    }
}
```

### 3. Accessibility with Animations

```swift
struct AccessibleAnimation: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Image(systemName: "figure.walk")
            .font(.system(size: 60))
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
            .accessibilityLabel("Walking figure")
            .accessibilityHint(reduceMotion ? "Static icon" : "Rotating animation")
    }
}
```

## Conclusion

SwiftUI's animation and gesture system provides:

1. **Declarative animations** that are easy to implement
2. **Powerful gesture recognizers** with composition support
3. **Performance optimizations** through transform animations
4. **Interactive experiences** with velocity and spring dynamics
5. **Accessibility support** with motion preferences

Key takeaways:
- Prefer transform animations over layout changes
- Use appropriate animation curves for different interactions
- Handle gesture conflicts with simultaneous gestures
- Always respect accessibility preferences
- Test animations on real devices for performance