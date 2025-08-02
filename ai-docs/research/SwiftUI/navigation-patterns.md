# SwiftUI Navigation Patterns

## Overview

Navigation is a critical aspect of iOS app architecture. This guide covers modern SwiftUI navigation patterns for iOS 18+, focusing on NavigationStack, programmatic navigation, and best practices.

## NavigationStack (iOS 16+)

### Basic NavigationStack

```swift
struct RuckNavigationExample: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            RuckListView()
                .navigationTitle("Ruck History")
                .navigationDestination(for: RuckSession.self) { session in
                    RuckDetailView(session: session)
                }
                .navigationDestination(for: Route.self) { route in
                    RouteDetailView(route: route)
                }
                .navigationDestination(for: User.self) { user in
                    ProfileView(user: user)
                }
        }
    }
}
```

### Type-Safe Navigation

```swift
// Define navigation destinations
enum AppDestination: Hashable {
    case ruckDetail(RuckSession)
    case routeDetail(Route)
    case profile(User)
    case settings
    case statistics(DateRange)
}

struct TypeSafeNavigation: View {
    @State private var path = [AppDestination]()
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .ruckDetail(let session):
                        RuckDetailView(session: session)
                    case .routeDetail(let route):
                        RouteDetailView(route: route)
                    case .profile(let user):
                        ProfileView(user: user)
                    case .settings:
                        SettingsView()
                    case .statistics(let dateRange):
                        StatisticsView(dateRange: dateRange)
                    }
                }
        }
        .environment(\.navigationPath, $path)
    }
}
```

### Programmatic Navigation

```swift
@Observable
class NavigationModel {
    var path = NavigationPath()
    
    func navigateToRuck(_ session: RuckSession) {
        path.append(session)
    }
    
    func navigateToRoute(_ route: Route) {
        path.append(route)
    }
    
    func navigateToRoot() {
        path.removeLast(path.count)
    }
    
    func popView() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func navigateToSettings() {
        // Navigate to specific view
        path.append(AppDestination.settings)
    }
}

struct NavigationContainer: View {
    @State private var navigation = NavigationModel()
    
    var body: some View {
        NavigationStack(path: $navigation.path) {
            ContentView()
                .navigationDestination(for: RuckSession.self) { session in
                    RuckDetailView(session: session)
                }
        }
        .environment(navigation)
    }
}
```

## Navigation Patterns

### 1. Tab-Based Navigation

```swift
struct MainTabView: View {
    @State private var selectedTab = Tab.activity
    @State private var activityPath = NavigationPath()
    @State private var routesPath = NavigationPath()
    @State private var progressPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    
    enum Tab {
        case activity, routes, progress, profile
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $activityPath) {
                ActivityView()
                    .navigationDestination(for: RuckSession.self) { session in
                        RuckDetailView(session: session)
                    }
            }
            .tabItem {
                Label("Activity", systemImage: "figure.walk")
            }
            .tag(Tab.activity)
            
            NavigationStack(path: $routesPath) {
                RoutesView()
                    .navigationDestination(for: Route.self) { route in
                        RouteDetailView(route: route)
                    }
            }
            .tabItem {
                Label("Routes", systemImage: "map")
            }
            .tag(Tab.routes)
            
            NavigationStack(path: $progressPath) {
                ProgressView()
            }
            .tabItem {
                Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(Tab.progress)
            
            NavigationStack(path: $profilePath) {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(Tab.profile)
        }
    }
}
```

### 2. Split View Navigation (iPad)

```swift
struct AdaptiveSplitView: View {
    @State private var selectedRuck: RuckSession?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            RuckListSidebar(selection: $selectedRuck)
                .navigationSplitViewColumnWidth(
                    min: 250,
                    ideal: 300,
                    max: 400
                )
        } content: {
            // Supplementary view
            if let ruck = selectedRuck {
                RuckMapView(session: ruck)
                    .navigationSplitViewColumnWidth(
                        min: 300,
                        ideal: 400
                    )
            } else {
                ContentUnavailableView(
                    "Select a Ruck",
                    systemImage: "figure.walk",
                    description: Text("Choose a ruck session to view details")
                )
            }
        } detail: {
            // Detail view
            if let ruck = selectedRuck {
                RuckDetailView(session: ruck)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "figure.walk"
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### 3. Modal Navigation

```swift
struct ModalNavigationExample: View {
    @State private var showingNewRuck = false
    @State private var showingSettings = false
    @State private var showingProfile = false
    
    var body: some View {
        NavigationStack {
            HomeView()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Ruck", systemImage: "plus") {
                            showingNewRuck = true
                        }
                    }
                    
                    ToolbarItem(placement: .navigation) {
                        Button("Profile", systemImage: "person.circle") {
                            showingProfile = true
                        }
                    }
                }
                .sheet(isPresented: $showingNewRuck) {
                    NewRuckFlow()
                }
                .fullScreenCover(isPresented: $showingProfile) {
                    ProfileNavigationView()
                }
        }
    }
}

// Modal with its own navigation
struct NewRuckFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            NewRuckSetupView()
                .navigationTitle("New Ruck")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .navigationDestination(for: String.self) { view in
                    switch view {
                    case "weight":
                        WeightSelectionView()
                    case "route":
                        RouteSelectionView()
                    case "gear":
                        GearChecklistView()
                    default:
                        EmptyView()
                    }
                }
        }
    }
}
```

## Deep Linking

### URL-Based Navigation

```swift
struct DeepLinkHandler: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView()
                .navigationDestination(for: RuckSession.self) { session in
                    RuckDetailView(session: session)
                }
                .navigationDestination(for: Route.self) { route in
                    RouteDetailView(route: route)
                }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Parse URL: rucktracker://ruck/123 or rucktracker://route/456
        guard let host = url.host else { return }
        
        switch host {
        case "ruck":
            if let ruckId = url.pathComponents.last,
               let ruck = fetchRuck(by: ruckId) {
                navigationPath.append(ruck)
            }
            
        case "route":
            if let routeId = url.pathComponents.last,
               let route = fetchRoute(by: routeId) {
                navigationPath.append(route)
            }
            
        case "new-ruck":
            // Handle new ruck creation
            navigationPath.append("new-ruck")
            
        default:
            break
        }
    }
}
```

### Universal Links

```swift
struct UniversalLinkHandler {
    static func handle(_ userActivity: NSUserActivity) -> AppDestination? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return nil
        }
        
        // Parse https://rucktracker.com/ruck/123
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let pathComponents = url.pathComponents
        
        if pathComponents.count >= 3 {
            switch pathComponents[1] {
            case "ruck":
                if let ruckId = pathComponents[2],
                   let ruck = DataManager.shared.fetchRuck(id: ruckId) {
                    return .ruckDetail(ruck)
                }
                
            case "route":
                if let routeId = pathComponents[2],
                   let route = DataManager.shared.fetchRoute(id: routeId) {
                    return .routeDetail(route)
                }
                
            default:
                break
            }
        }
        
        return nil
    }
}
```

## State Restoration

### Saving Navigation State

```swift
extension NavigationPath {
    func encode() -> Data? {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(self)
        } catch {
            return nil
        }
    }
    
    static func decode(from data: Data) -> NavigationPath? {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(NavigationPath.self, from: data)
        } catch {
            return nil
        }
    }
}

struct PersistentNavigation: View {
    @SceneStorage("navigationPath") private var pathData: Data?
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ContentView()
                .navigationDestination(for: RuckSession.self) { session in
                    RuckDetailView(session: session)
                }
        }
        .onAppear {
            if let data = pathData,
               let decoded = NavigationPath.decode(from: data) {
                navigationPath = decoded
            }
        }
        .onChange(of: navigationPath) { _, newPath in
            pathData = newPath.encode()
        }
    }
}
```

## Navigation Styling

### Custom Navigation Bar

```swift
struct CustomNavigationBar: View {
    var body: some View {
        NavigationStack {
            ContentView()
                .navigationTitle("Ruck Tracker")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.armyGreen.opacity(0.1), for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// Custom back button
struct CustomBackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text("Back")
            }
        }
    }
}
```

### Navigation Transitions

```swift
struct CustomTransitions: View {
    @Namespace private var namespace
    @State private var selectedRuck: RuckSession?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                    ForEach(rucks) { ruck in
                        RuckCard(ruck: ruck)
                            .matchedGeometryEffect(
                                id: ruck.id,
                                in: namespace
                            )
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedRuck = ruck
                                }
                            }
                    }
                }
            }
            .navigationDestination(item: $selectedRuck) { ruck in
                RuckDetailView(ruck: ruck)
                    .navigationTransition(.zoom(sourceID: ruck.id, in: namespace))
            }
        }
    }
}
```

## Best Practices

### 1. Navigation State Management

```swift
// Centralized navigation state
@Observable
class AppNavigation {
    var tabSelection: Tab = .home
    var homePath = NavigationPath()
    var activityPath = NavigationPath()
    var profilePath = NavigationPath()
    
    func reset() {
        tabSelection = .home
        homePath = NavigationPath()
        activityPath = NavigationPath()
        profilePath = NavigationPath()
    }
    
    func navigateToRuck(_ ruck: RuckSession, from tab: Tab) {
        tabSelection = tab
        
        switch tab {
        case .home:
            homePath.append(ruck)
        case .activity:
            activityPath.append(ruck)
        default:
            break
        }
    }
}
```

### 2. Navigation Guards

```swift
struct NavigationGuard: ViewModifier {
    let canNavigate: Bool
    let message: String
    
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(!canNavigate)
            .toolbar {
                if !canNavigate {
                    ToolbarItem(placement: .navigation) {
                        Button("Cancel") {
                            // Handle cancellation
                        }
                    }
                }
            }
            .alert("Unsaved Changes", isPresented: .constant(!canNavigate)) {
                Button("Discard", role: .destructive) {
                    // Navigate away
                }
                Button("Save") {
                    // Save then navigate
                }
                Button("Cancel", role: .cancel) {
                    // Stay on current view
                }
            } message: {
                Text(message)
            }
    }
}
```

### 3. Navigation Analytics

```swift
struct NavigationTracking: ViewModifier {
    let screenName: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Analytics.logScreenView(screenName)
            }
            .navigationDestination(for: RuckSession.self) { session in
                RuckDetailView(session: session)
                    .modifier(NavigationTracking(screenName: "RuckDetail"))
            }
    }
}
```

## Common Patterns

### Wizard/Flow Navigation

```swift
struct RuckSetupWizard: View {
    @State private var currentStep = 0
    @State private var ruckData = RuckSetupData()
    
    private let steps = ["Weight", "Route", "Gear", "Summary"]
    
    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(steps.count))
                    .padding()
                
                // Current step
                Group {
                    switch currentStep {
                    case 0:
                        WeightSelectionStep(weight: $ruckData.weight)
                    case 1:
                        RouteSelectionStep(route: $ruckData.route)
                    case 2:
                        GearChecklistStep(gear: $ruckData.gear)
                    case 3:
                        SummaryStep(data: ruckData)
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut, value: currentStep)
                
                // Navigation buttons
                HStack {
                    Button("Previous") {
                        currentStep -= 1
                    }
                    .disabled(currentStep == 0)
                    
                    Spacer()
                    
                    Button(currentStep == steps.count - 1 ? "Start Ruck" : "Next") {
                        if currentStep == steps.count - 1 {
                            startRuck()
                        } else {
                            currentStep += 1
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(steps[currentStep])
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

### Conditional Navigation

```swift
struct ConditionalNavigation: View {
    @State private var isAuthenticated = false
    @State private var hasCompletedOnboarding = false
    
    var body: some View {
        NavigationStack {
            if !isAuthenticated {
                LoginView()
                    .navigationDestination(isPresented: .constant(true)) {
                        if hasCompletedOnboarding {
                            MainAppView()
                        } else {
                            OnboardingFlow()
                        }
                    }
            } else if !hasCompletedOnboarding {
                OnboardingFlow()
            } else {
                MainAppView()
            }
        }
    }
}
```

## Performance Optimization

### Lazy Navigation Loading

```swift
struct LazyNavigationDestination<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
        LazyView(content)
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

// Usage
.navigationDestination(for: RuckSession.self) { session in
    LazyNavigationDestination {
        RuckDetailView(session: session)
    }
}
```

## Conclusion

Modern SwiftUI navigation with NavigationStack provides:

1. **Type-safe navigation** with clear destination handling
2. **Programmatic control** over navigation state
3. **Platform-adaptive layouts** for iPhone and iPad
4. **Deep linking support** for external navigation
5. **State restoration** for better user experience

Key takeaways:
- Use NavigationStack over NavigationView for iOS 16+
- Implement type-safe navigation with enums
- Handle navigation state centrally
- Support both push and modal navigation patterns
- Test navigation flows thoroughly on all device types