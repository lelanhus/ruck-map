import SwiftUI
import CoreHaptics
import Foundation
import UIKit

/// Army Green Design System Colors
struct ArmyGreenDesign {
    // Base army green palette
    static let primary = Color(red: 0.2, green: 0.3, blue: 0.2)           // #334D33
    static let secondary = Color(red: 0.3, green: 0.4, blue: 0.3)         // #4D664D
    static let tertiary = Color(red: 0.4, green: 0.5, blue: 0.4)          // #668066
    static let accent = Color(red: 0.6, green: 0.7, blue: 0.5)            // #99B380
    static let dark = Color(red: 0.1, green: 0.2, blue: 0.1)              // #1A331A
    static let light = Color(red: 0.8, green: 0.85, blue: 0.8)            // #CCD9CC
    static let bright = Color(red: 0.7, green: 0.8, blue: 0.6)            // #B3CC99
    static let natural = Color(red: 0.5, green: 0.6, blue: 0.4)           // #809966
    
    // Adaptive variations using SwiftUI's mixing system (iOS 18+)
    static let primaryLight = primary.mix(with: .white, by: 0.3)
    static let primaryDark = primary.mix(with: .black, by: 0.2)
    static let secondaryLight = secondary.mix(with: .white, by: 0.2)
    static let accentMuted = accent.mix(with: .gray, by: 0.3)
    
    // Hierarchical variations
    static let textPrimary = primary
    static let textSecondary = secondary
    static let textTertiary = tertiary
}

/// Terrain Override State Manager
@MainActor
@Observable
final class TerrainOverrideState {
    var isOverrideActive: Bool = false
    var overrideStartTime: Date?
    var overrideDuration: TimeInterval = 600 // 10 minutes default
    var showQuickPicker: Bool = false
    var selectedTerrain: TerrainType = .trail
    
    // Auto-revert functionality
    private var autoRevertTimer: Timer?
    
    func startOverride(terrain: TerrainType, duration: TimeInterval = 600) {
        selectedTerrain = terrain
        isOverrideActive = true
        overrideStartTime = Date()
        overrideDuration = duration
        showQuickPicker = false
        
        // Start auto-revert timer
        autoRevertTimer?.invalidate()
        autoRevertTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearOverride()
            }
        }
    }
    
    func clearOverride() {
        isOverrideActive = false
        overrideStartTime = nil
        showQuickPicker = false
        autoRevertTimer?.invalidate()
        autoRevertTimer = nil
    }
    
    var remainingTime: TimeInterval {
        guard let startTime = overrideStartTime, isOverrideActive else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, overrideDuration - elapsed)
    }
    
    var remainingTimeFormatted: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Main Terrain Override View with modern SwiftUI patterns
struct TerrainOverrideView: View {
    let terrainDetector: TerrainDetector
    @State private var overrideState = TerrainOverrideState()
    @State private var hapticEngine: CHHapticEngine?
    @State private var showDurationPicker = false
    
    private let overrideDurations: [TimeInterval] = [300, 600, 900, 1800] // 5min, 10min, 15min, 30min
    
    private var currentTerrain: TerrainType {
        overrideState.isOverrideActive ? overrideState.selectedTerrain : terrainDetector.currentTerrain
    }
    
    private var confidenceColor: Color {
        if overrideState.isOverrideActive {
            return ArmyGreenDesign.accent
        } else if terrainDetector.confidence > 0.85 {
            return ArmyGreenDesign.bright
        } else if terrainDetector.confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Main terrain display card
            TerrainDisplayCard(
                terrain: currentTerrain,
                confidence: terrainDetector.confidence,
                isOverrideActive: overrideState.isOverrideActive,
                remainingTime: overrideState.remainingTimeFormatted
            )
            .onLongPressGesture(minimumDuration: 0.6) {
                triggerHapticFeedback(.light)
                withAnimation(.easeInOut(duration: 0.3)) {
                    overrideState.showQuickPicker.toggle()
                }
            }
            .onTapGesture {
                if overrideState.isOverrideActive {
                    triggerHapticFeedback(.medium)
                    showOverrideClearConfirmation()
                } else {
                    triggerHapticFeedback(.light)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        overrideState.showQuickPicker.toggle()
                    }
                }
            }
            
            // Quick terrain selection (expandable)
            if overrideState.showQuickPicker {
                TerrainQuickPickerView(
                    currentTerrain: currentTerrain,
                    onTerrainSelected: { terrain in
                        selectTerrain(terrain)
                    },
                    onDurationTapped: {
                        showDurationPicker = true
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: overrideState.showQuickPicker)
        .onAppear {
            setupHaptics()
        }
        .actionSheet(isPresented: $showDurationPicker) {
            ActionSheet(
                title: Text("Override Duration"),
                message: Text("How long should the terrain override last?"),
                buttons: overrideDurations.map { duration in
                    .default(Text(formatDuration(duration))) {
                        overrideState.overrideDuration = duration
                        if overrideState.isOverrideActive {
                            // Restart with new duration
                            overrideState.startOverride(
                                terrain: overrideState.selectedTerrain,
                                duration: duration
                            )
                            terrainDetector.setManualTerrain(overrideState.selectedTerrain)
                        }
                    }
                } + [.cancel()]
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    private func triggerHapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: type)
        impactFeedback.impactOccurred()
    }
    
    private func selectTerrain(_ terrain: TerrainType) {
        triggerHapticFeedback(.medium)
        overrideState.startOverride(terrain: terrain, duration: overrideState.overrideDuration)
        terrainDetector.setManualTerrain(terrain)
    }
    
    private func showOverrideClearConfirmation() {
        let alert = UIAlertController(
            title: "Clear Override?",
            message: "This will return to automatic terrain detection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.overrideState.clearOverride()
            self.triggerHapticFeedback(.heavy)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

// MARK: - Terrain Display Card

struct TerrainDisplayCard: View {
    let terrain: TerrainType
    let confidence: Double
    let isOverrideActive: Bool
    let remainingTime: String
    
    private var iconColor: Color {
        if isOverrideActive {
            return ArmyGreenDesign.accent
        } else if confidence > 0.85 {
            return ArmyGreenDesign.bright
        } else if confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                ArmyGreenDesign.primaryLight.opacity(0.9),
                ArmyGreenDesign.secondary.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Terrain icon with confidence indicator
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: terrain.iconName)
                    .font(.title)
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, isActive: isOverrideActive)
            }
            
            // Terrain info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(terrain.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(ArmyGreenDesign.textPrimary)
                    
                    if isOverrideActive {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(ArmyGreenDesign.accent)
                    }
                }
                
                HStack(spacing: 12) {
                    Text("Factor: \(String(format: "%.1f", terrain.terrainFactor))×")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(ArmyGreenDesign.textSecondary)
                    
                    if isOverrideActive {
                        Text("⏱ \(remainingTime)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(ArmyGreenDesign.accent)
                    } else {
                        confidenceIndicator
                    }
                }
                
                // Long press hint
                Text(isOverrideActive ? "Tap to clear • Long press for options" : "Tap or long press to override")
                    .font(.caption2)
                    .foregroundStyle(ArmyGreenDesign.textTertiary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(backgroundGradient)
        .cornerRadius(16)
        .shadow(color: ArmyGreenDesign.dark.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isOverrideActive ? ArmyGreenDesign.accent : ArmyGreenDesign.primary.opacity(0.3),
                    lineWidth: isOverrideActive ? 2 : 1
                )
        )
        .scaleEffect(isOverrideActive ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isOverrideActive)
    }
    
    @ViewBuilder
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(iconColor)
                .frame(width: 8, height: 8)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(ArmyGreenDesign.textSecondary)
        }
    }
}

// MARK: - Quick Picker View

struct TerrainQuickPickerView: View {
    let currentTerrain: TerrainType
    let onTerrainSelected: (TerrainType) -> Void
    let onDurationTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Duration selector
            Button(action: onDurationTapped) {
                HStack {
                    Image(systemName: "clock")
                    Text("Duration")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(12)
                .background(ArmyGreenDesign.secondaryLight)
                .cornerRadius(10)
                .foregroundStyle(ArmyGreenDesign.textPrimary)
            }
            
            // Terrain grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(TerrainType.allCases, id: \.self) { terrain in
                    TerrainQuickSelectButton(
                        terrain: terrain,
                        isSelected: terrain == currentTerrain,
                        action: {
                            onTerrainSelected(terrain)
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ArmyGreenDesign.primaryLight.opacity(0.95))
                .shadow(color: ArmyGreenDesign.dark.opacity(0.1), radius: 6, x: 0, y: 2)
        )
    }
}

/// Modern terrain selection button with army green design
struct TerrainQuickSelectButton: View {
    let terrain: TerrainType
    let isSelected: Bool
    let action: () -> Void
    
    private var buttonBackground: Color {
        if isSelected {
            return ArmyGreenDesign.accent
        } else {
            return ArmyGreenDesign.light.opacity(0.8)
        }
    }
    
    private var textColor: Color {
        isSelected ? .white : ArmyGreenDesign.textPrimary
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: terrain.iconName)
                    .font(.title3)
                    .foregroundStyle(textColor)
                    .symbolEffect(.bounce, value: isSelected)
                
                Text(terrain.displayName.components(separatedBy: " ").first ?? terrain.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                
                Text("\(String(format: "%.1f", terrain.terrainFactor))×")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(textColor.opacity(0.8))
            }
            .frame(width: 70, height: 75)
            .background(buttonBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? ArmyGreenDesign.accent : ArmyGreenDesign.primary.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityLabel("\(terrain.displayName), terrain factor \(String(format: "%.1f", terrain.terrainFactor))")
        .accessibilityHint("Double tap to select this terrain type")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Compact Components

/// Compact terrain indicator for use in tracking views
struct TerrainIndicator: View {
    let terrainDetector: TerrainDetector
    let overrideState: TerrainOverrideState?
    let showLabel: Bool
    
    init(terrainDetector: TerrainDetector, overrideState: TerrainOverrideState? = nil, showLabel: Bool = true) {
        self.terrainDetector = terrainDetector
        self.overrideState = overrideState
        self.showLabel = showLabel
    }
    
    private var currentTerrain: TerrainType {
        overrideState?.isOverrideActive == true ? overrideState!.selectedTerrain : terrainDetector.currentTerrain
    }
    
    private var isOverrideActive: Bool {
        overrideState?.isOverrideActive == true
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: currentTerrain.iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 16, weight: .medium))
                .symbolEffect(.pulse, isActive: isOverrideActive)
            
            if showLabel {
                Text(currentTerrain.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(ArmyGreenDesign.textPrimary)
            }
            
            // Confidence/status indicator
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ArmyGreenDesign.light.opacity(0.9))
                .stroke(ArmyGreenDesign.primary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var iconColor: Color {
        if isOverrideActive {
            return ArmyGreenDesign.accent
        } else if terrainDetector.confidence > 0.85 {
            return ArmyGreenDesign.bright
        } else if terrainDetector.confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var confidenceColor: Color {
        if isOverrideActive {
            return ArmyGreenDesign.accent
        } else if terrainDetector.confidence > 0.85 {
            return ArmyGreenDesign.bright
        } else if terrainDetector.confidence > 0.6 {
            return .yellow
        } else {
            return .red
        }
    }
}

/// Compact terrain overlay for main tracking screen
struct TerrainOverlay: View {
    let terrainDetector: TerrainDetector
    @State private var overrideState = TerrainOverrideState()
    @State private var showFullOverride = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    // Compact indicator
                    TerrainIndicator(
                        terrainDetector: terrainDetector,
                        overrideState: overrideState,
                        showLabel: false
                    )
                    .onLongPressGesture(minimumDuration: 0.8) {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showFullOverride = true
                    }
                    
                    // Remaining time if override is active
                    if overrideState.isOverrideActive {
                        Text(overrideState.remainingTimeFormatted)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(ArmyGreenDesign.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ArmyGreenDesign.light.opacity(0.9))
                            )
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 60) // Account for status bar and navigation
            
            Spacer()
        }
        .sheet(isPresented: $showFullOverride) {
            NavigationStack {
                TerrainOverrideView(terrainDetector: terrainDetector)
                    .navigationTitle("Terrain Override")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showFullOverride = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

/// Terrain factor display for calorie calculations with army green design
struct TerrainFactorView: View {
    let terrainDetector: TerrainDetector
    let overrideState: TerrainOverrideState?
    
    private var currentTerrain: TerrainType {
        overrideState?.isOverrideActive == true ? overrideState!.selectedTerrain : terrainDetector.currentTerrain
    }
    
    private var isOverrideActive: Bool {
        overrideState?.isOverrideActive == true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Terrain Factor")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(ArmyGreenDesign.textSecondary)
                
                Spacer()
                
                if isOverrideActive {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("OVERRIDE")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(ArmyGreenDesign.accent)
                }
            }
            
            Text("\(String(format: "%.1f", currentTerrain.terrainFactor))×")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(ArmyGreenDesign.primary)
            
            Text(currentTerrain.displayName)
                .font(.caption)
                .foregroundStyle(ArmyGreenDesign.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            ArmyGreenDesign.light.opacity(0.9),
                            ArmyGreenDesign.primaryLight.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .stroke(ArmyGreenDesign.primary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: ArmyGreenDesign.dark.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Compatibility Layer

/// Compatibility adapter for the existing LocationTrackingManager
@MainActor
struct TerrainDetectorAdapter {
    let locationManager: LocationTrackingManager
    
    var currentTerrain: TerrainType {
        locationManager.currentDetectedTerrain
    }
    
    var confidence: Double {
        locationManager.terrainDetectionConfidence
    }
    
    func setManualTerrain(_ terrain: TerrainType) {
        locationManager.setManualTerrainOverride(terrain)
    }
}

/// Compatibility terrain override state for existing LocationTrackingManager
@MainActor
@Observable
final class TerrainOverrideCompatState {
    private let locationManager: LocationTrackingManager
    
    var isOverrideActive: Bool {
        locationManager.isTerrainOverrideActive
    }
    
    var overrideStartTime: Date?
    var overrideDuration: TimeInterval = 600 // 10 minutes default
    var showQuickPicker: Bool = false
    var selectedTerrain: TerrainType {
        get { locationManager.currentDetectedTerrain }
        set { 
            locationManager.setManualTerrainOverride(newValue)
            overrideStartTime = Date()
            showQuickPicker = false
            startAutoRevertTimer()
        }
    }
    
    // Auto-revert functionality
    private var autoRevertTimer: Timer?
    
    init(locationManager: LocationTrackingManager) {
        self.locationManager = locationManager
    }
    
    func startOverride(terrain: TerrainType, duration: TimeInterval = 600) {
        selectedTerrain = terrain
        overrideStartTime = Date()
        overrideDuration = duration
        showQuickPicker = false
        startAutoRevertTimer()
    }
    
    func clearOverride() {
        locationManager.clearTerrainOverride()
        overrideStartTime = nil
        showQuickPicker = false
        autoRevertTimer?.invalidate()
        autoRevertTimer = nil
    }
    
    private func startAutoRevertTimer() {
        autoRevertTimer?.invalidate()
        autoRevertTimer = Timer.scheduledTimer(withTimeInterval: overrideDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearOverride()
            }
        }
    }
    
    var remainingTime: TimeInterval {
        guard let startTime = overrideStartTime, isOverrideActive else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, overrideDuration - elapsed)
    }
    
    var remainingTimeFormatted: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Compatibility terrain override view for existing LocationTrackingManager
struct TerrainOverrideCompatView: View {
    let locationManager: LocationTrackingManager
    @State private var overrideState: TerrainOverrideCompatState
    @State private var hapticEngine: CHHapticEngine?
    @State private var showDurationPicker = false
    
    init(locationManager: LocationTrackingManager) {
        self.locationManager = locationManager
        self._overrideState = State(initialValue: TerrainOverrideCompatState(locationManager: locationManager))
    }
    
    private let overrideDurations: [TimeInterval] = [300, 600, 900, 1800] // 5min, 10min, 15min, 30min
    
    private var currentTerrain: TerrainType {
        locationManager.currentDetectedTerrain
    }
    
    private var confidenceColor: Color {
        if overrideState.isOverrideActive {
            return ArmyGreenDesign.accent
        } else if locationManager.terrainDetectionConfidence > 0.85 {
            return ArmyGreenDesign.bright
        } else if locationManager.terrainDetectionConfidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Main terrain display card
            TerrainDisplayCard(
                terrain: currentTerrain,
                confidence: locationManager.terrainDetectionConfidence,
                isOverrideActive: overrideState.isOverrideActive,
                remainingTime: overrideState.remainingTimeFormatted
            )
            .onLongPressGesture(minimumDuration: 0.6) {
                triggerHapticFeedback(.light)
                withAnimation(.easeInOut(duration: 0.3)) {
                    overrideState.showQuickPicker.toggle()
                }
            }
            .onTapGesture {
                if overrideState.isOverrideActive {
                    triggerHapticFeedback(.medium)
                    showOverrideClearConfirmation()
                } else {
                    triggerHapticFeedback(.light)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        overrideState.showQuickPicker.toggle()
                    }
                }
            }
            
            // Quick terrain selection (expandable)
            if overrideState.showQuickPicker {
                TerrainQuickPickerCompatView(
                    locationManager: locationManager,
                    currentTerrain: currentTerrain,
                    onTerrainSelected: { terrain in
                        selectTerrain(terrain)
                    },
                    onDurationTapped: {
                        showDurationPicker = true
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: overrideState.showQuickPicker)
        .onAppear {
            setupHaptics()
        }
        .actionSheet(isPresented: $showDurationPicker) {
            ActionSheet(
                title: Text("Override Duration"),
                message: Text("How long should the terrain override last?"),
                buttons: overrideDurations.map { duration in
                    .default(Text(formatDuration(duration))) {
                        overrideState.overrideDuration = duration
                        if overrideState.isOverrideActive {
                            // Restart with new duration
                            overrideState.startOverride(
                                terrain: overrideState.selectedTerrain,
                                duration: duration
                            )
                        }
                    }
                } + [.cancel()]
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    private func triggerHapticFeedback(_ type: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: type)
        impactFeedback.impactOccurred()
    }
    
    private func selectTerrain(_ terrain: TerrainType) {
        triggerHapticFeedback(.medium)
        overrideState.startOverride(terrain: terrain, duration: overrideState.overrideDuration)
    }
    
    private func showOverrideClearConfirmation() {
        let alert = UIAlertController(
            title: "Clear Override?",
            message: "This will return to automatic terrain detection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.overrideState.clearOverride()
            self.triggerHapticFeedback(.heavy)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

/// Compatibility quick picker for existing LocationTrackingManager
struct TerrainQuickPickerCompatView: View {
    let locationManager: LocationTrackingManager
    let currentTerrain: TerrainType
    let onTerrainSelected: (TerrainType) -> Void
    let onDurationTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Duration selector
            Button(action: onDurationTapped) {
                HStack {
                    Image(systemName: "clock")
                    Text("Duration")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(12)
                .background(ArmyGreenDesign.secondaryLight)
                .cornerRadius(10)
                .foregroundStyle(ArmyGreenDesign.textPrimary)
            }
            
            // Terrain grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(TerrainType.allCases, id: \.self) { terrain in
                    TerrainQuickSelectButton(
                        terrain: terrain,
                        isSelected: terrain == currentTerrain,
                        action: {
                            onTerrainSelected(terrain)
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ArmyGreenDesign.primaryLight.opacity(0.95))
                .shadow(color: ArmyGreenDesign.dark.opacity(0.1), radius: 6, x: 0, y: 2)
        )
    }
}

/// Compact terrain overlay for the main tracking screen
struct TerrainOverlayCompat: View {
    let locationManager: LocationTrackingManager
    @State private var overrideState: TerrainOverrideCompatState
    @State private var showFullOverride = false
    
    init(locationManager: LocationTrackingManager) {
        self.locationManager = locationManager
        self._overrideState = State(initialValue: TerrainOverrideCompatState(locationManager: locationManager))
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    // Compact indicator
                    TerrainIndicatorCompat(
                        locationManager: locationManager,
                        overrideState: overrideState,
                        showLabel: false
                    )
                    .onLongPressGesture(minimumDuration: 0.8) {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showFullOverride = true
                    }
                    
                    // Remaining time if override is active
                    if overrideState.isOverrideActive {
                        Text(overrideState.remainingTimeFormatted)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(ArmyGreenDesign.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ArmyGreenDesign.light.opacity(0.9))
                            )
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 60) // Account for status bar and navigation
            
            Spacer()
        }
        .sheet(isPresented: $showFullOverride) {
            NavigationStack {
                TerrainOverrideCompatView(locationManager: locationManager)
                    .navigationTitle("Terrain Override")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showFullOverride = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

/// Compact terrain indicator compatible with LocationTrackingManager
struct TerrainIndicatorCompat: View {
    let locationManager: LocationTrackingManager
    let overrideState: TerrainOverrideCompatState?
    let showLabel: Bool
    
    init(locationManager: LocationTrackingManager, overrideState: TerrainOverrideCompatState? = nil, showLabel: Bool = true) {
        self.locationManager = locationManager
        self.overrideState = overrideState
        self.showLabel = showLabel
    }
    
    private var currentTerrain: TerrainType {
        locationManager.currentDetectedTerrain
    }
    
    private var isOverrideActive: Bool {
        overrideState?.isOverrideActive ?? locationManager.isTerrainOverrideActive
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: currentTerrain.iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 16, weight: .medium))
                .symbolEffect(.pulse, isActive: isOverrideActive)
            
            if showLabel {
                Text(currentTerrain.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(ArmyGreenDesign.textPrimary)
            }
            
            // Confidence/status indicator
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ArmyGreenDesign.light.opacity(0.9))
                .stroke(ArmyGreenDesign.primary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var iconColor: Color {
        if isOverrideActive {
            return ArmyGreenDesign.accent
        } else if locationManager.terrainDetectionConfidence > 0.85 {
            return ArmyGreenDesign.bright
        } else if locationManager.terrainDetectionConfidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var confidenceColor: Color {
        if isOverrideActive {
            return ArmyGreenDesign.accent
        } else if locationManager.terrainDetectionConfidence > 0.85 {
            return ArmyGreenDesign.bright
        } else if locationManager.terrainDetectionConfidence > 0.6 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - SwiftUI Previews

#Preview("Terrain Override - Main") {
    let terrainDetector = TerrainDetector()
    
    VStack {
        TerrainOverrideView(terrainDetector: terrainDetector)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Terrain Indicator - Compact") {
    let terrainDetector = TerrainDetector()
    
    VStack(spacing: 20) {
        TerrainIndicator(terrainDetector: terrainDetector)
        TerrainIndicator(terrainDetector: terrainDetector, showLabel: false)
    }
    .padding()
}

#Preview("Terrain Factor View") {
    let terrainDetector = TerrainDetector()
    
    TerrainFactorView(terrainDetector: terrainDetector, overrideState: nil)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Terrain Overlay") {
    let terrainDetector = TerrainDetector()
    
    ZStack {
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .frame(height: 400)
        
        TerrainOverlay(terrainDetector: terrainDetector)
    }
}

#Preview("Army Green Design System") {
    VStack(spacing: 12) {
        HStack(spacing: 8) {
            ForEach([
                ("Primary", ArmyGreenDesign.primary),
                ("Secondary", ArmyGreenDesign.secondary),
                ("Accent", ArmyGreenDesign.accent),
                ("Light", ArmyGreenDesign.light)
            ], id: \.0) { name, color in
                VStack {
                    Rectangle()
                        .fill(color)
                        .frame(width: 60, height: 40)
                        .cornerRadius(8)
                    Text(name)
                        .font(.caption2)
                }
            }
        }
        
        Text("Army Green Design System")
            .font(.headline)
            .foregroundStyle(ArmyGreenDesign.textPrimary)
    }
    .padding()
}