import SwiftUI
import AVFoundation
import Charts

// MARK: - Accessibility Enhancements for Analytics Charts

/// Audio feedback manager for chart interactions and data changes
@MainActor
class ChartAccessibilityManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var audioWorkItems: [DispatchWorkItem] = []
    
    @Published var isAudioGraphEnabled: Bool = false
    @Published var announceDataChanges: Bool = true
    @Published var useHapticFeedback: Bool = true
    
    init() {
        setupAudioGraph()
        setupAccessibilityNotifications()
    }
    
    deinit {
        // Cancel any pending audio work items
        audioWorkItems.forEach { $0.cancel() }
        audioWorkItems.removeAll()
        
        // Clean up audio resources
        player.stop()
        audioEngine.stop()
        audioEngine.reset()
    }
    
    // MARK: - Audio Graph Setup
    
    private func setupAudioGraph() {
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func setupAccessibilityNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isAudioGraphEnabled = UIAccessibility.isVoiceOverRunning
        }
    }
    
    // MARK: - Chart Data Sonification
    
    func playAudioGraph(for dataPoints: [Double], metric: String) {
        guard isAudioGraphEnabled else { return }
        
        let normalizedData = normalizeDataForAudio(dataPoints)
        playToneSequence(normalizedData, metric: metric)
    }
    
    private func normalizeDataForAudio(_ data: [Double]) -> [Double] {
        guard let min = data.min(), let max = data.max(), max > min else {
            return data.map { _ in 0.5 } // Return middle values if no variation
        }
        
        return data.map { ($0 - min) / (max - min) }
    }
    
    private func playToneSequence(_ normalizedData: [Double], metric: String) {
        // Cancel any existing audio work items
        audioWorkItems.forEach { $0.cancel() }
        audioWorkItems.removeAll()
        
        let baseFrequency: Float = 220.0 // A3
        let frequencyRange: Float = 440.0 // One octave
        let noteDuration: Float = 0.3
        
        for (index, value) in normalizedData.enumerated() {
            let frequency = baseFrequency + (Float(value) * frequencyRange)
            let delay = Float(index) * noteDuration
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.playTone(frequency: frequency, duration: noteDuration)
            }
            audioWorkItems.append(workItem)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(delay), execute: workItem)
        }
        
        // Announce completion
        let totalDuration = Double(normalizedData.count) * Double(noteDuration)
        let completionWorkItem = DispatchWorkItem { [weak self] in
            self?.announceMessage("Audio graph complete for \(metric)")
        }
        audioWorkItems.append(completionWorkItem)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.5, execute: completionWorkItem)
    }
    
    private func playTone(frequency: Float, duration: Float) {
        let sampleRate: Float = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else {
            return
        }
        
        buffer.frameLength = frameCount
        
        let samples = buffer.floatChannelData?[0]
        for i in 0..<Int(frameCount) {
            let sampleIndex = Float(i)
            let amplitude: Float = 0.1
            samples?[i] = amplitude * sin(2.0 * Float.pi * frequency * sampleIndex / sampleRate)
        }
        
        player.scheduleBuffer(buffer, at: nil)
        if !player.isPlaying {
            player.play()
        }
    }
    
    // MARK: - Voice Announcements
    
    func announceMessage(_ message: String, priority: AVSpeechUtteranceNotificationPriority = .default) {
        guard announceDataChanges else { return }
        
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 0.8
        
        // Stop current speech if needed
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        synthesizer.speak(utterance)
    }
    
    func announceChartSelection(_ description: String) {
        announceMessage(description, priority: .high)
        
        if useHapticFeedback {
            hapticFeedback.impactOccurred()
        }
    }
    
    func announceDataUpdate(_ updateDescription: String) {
        announceMessage("Chart updated: \(updateDescription)")
    }
    
    func announcePersonalRecord(_ recordDescription: String) {
        announceMessage("Personal record achieved: \(recordDescription)", priority: .high)
        
        // Special haptic pattern for achievements
        if useHapticFeedback {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    func announceStreakAchievement(_ streak: Int) {
        let message = "Training streak: \(streak) week\(streak == 1 ? "" : "s")"
        announceMessage(message, priority: .high)
        
        if useHapticFeedback {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - Accessibility Modifiers

extension View {
    /// Adds comprehensive accessibility support to chart views
    func chartAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        actions: [AccessibilityActionKind: () -> Void] = [:]
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits.union([.allowsDirectInteraction]))
            .accessibilityActions {
                ForEach(Array(actions.keys), id: \.self) { actionKind in
                    Button(actionKind.localizedName) {
                        actions[actionKind]?()
                    }
                }
            }
    }
    
    /// Adds rotor navigation support for chart elements
    func chartRotorSupport<T: Identifiable>(
        items: [T],
        label: @escaping (T) -> String,
        onSelection: @escaping (T) -> Void
    ) -> some View {
        self.accessibilityRotor("Chart Data Points") {
            ForEach(items) { item in
                AccessibilityRotorEntry(label(item), id: item.id) {
                    onSelection(item)
                }
            }
        }
    }
    
    /// Supports Dynamic Type scaling
    func dynamicTypeSupport(category: DynamicTypeCategory = .body) -> some View {
        self.font(.system(size: category.baseSize, weight: .regular, design: .default))
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}

// MARK: - Dynamic Type Categories

enum DynamicTypeCategory {
    case caption, body, headline, title
    
    var baseSize: CGFloat {
        switch self {
        case .caption: return 12
        case .body: return 16
        case .headline: return 18
        case .title: return 22
        }
    }
}

// MARK: - Accessibility Action Kinds

enum AccessibilityActionKind: CaseIterable {
    case playAudioGraph
    case announceDetails
    case showDataTable
    case toggleComparison
    case adjustTimeRange
    case exportData
    
    var localizedName: String {
        switch self {
        case .playAudioGraph: return "Play Audio Graph"
        case .announceDetails: return "Announce Details"
        case .showDataTable: return "Show Data Table"
        case .toggleComparison: return "Toggle Comparison"
        case .adjustTimeRange: return "Adjust Time Range"
        case .exportData: return "Export Data"
        }
    }
}

// MARK: - Chart Data Table View

struct ChartDataTableView: View {
    let title: String
    let headers: [String]
    let rows: [[String]]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    // Headers
                    HStack {
                        ForEach(headers, id: \.self) { header in
                            Text(header)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    
                    Divider()
                    
                    // Data rows
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack {
                            ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                                Text(cell)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("\(headers[cellIndex]): \(cell)")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityLabel("Data table for \(title)")
        .accessibilityHint("Swipe up and down to navigate through data rows")
    }
}

// MARK: - Accessibility Preferences

struct AccessibilityPreferences {
    static let shared = AccessibilityPreferences()
    
    var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    var prefersCrossFadeTransitions: Bool {
        UIAccessibility.prefersCrossFadeTransitions
    }
    
    var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    var isSwitchControlRunning: Bool {
        UIAccessibility.isSwitchControlRunning
    }
    
    var isReduceTransparencyEnabled: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }
    
    var isDarkerSystemColorsEnabled: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    var shouldUseHighContrast: Bool {
        isDarkerSystemColorsEnabled || isReduceTransparencyEnabled
    }
}

// MARK: - Color Accessibility Extensions

extension Color {
    /// Returns a high contrast version of the color when needed
    func highContrastAdapted() -> Color {
        if AccessibilityPreferences.shared.shouldUseHighContrast {
            return self.opacity(1.0)
        }
        return self
    }
    
    /// Returns colors that meet WCAG AA contrast requirements
    static func accessibleForeground(on background: Color) -> Color {
        // Simplified contrast calculation - in production, use proper WCAG algorithms
        return background.luminance > 0.5 ? .black : .white
    }
    
    private var luminance: Double {
        // Simplified luminance calculation
        // In production, implement proper sRGB to linear RGB conversion
        return 0.5 // Placeholder
    }
}

// MARK: - Pattern Overlays for Color Blind Users

struct PatternOverlay: View {
    let pattern: Pattern
    let color: Color
    
    enum Pattern {
        case dots, stripes, crosshatch, solid
        
        var accessibilityDescription: String {
            switch self {
            case .dots: return "dotted pattern"
            case .stripes: return "striped pattern" 
            case .crosshatch: return "crosshatch pattern"
            case .solid: return "solid pattern"
            }
        }
    }
    
    var body: some View {
        switch pattern {
        case .dots:
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
                .accessibilityHidden(true)
        case .stripes:
            Rectangle()
                .fill(color)
                .mask(
                    VStack(spacing: 2) {
                        ForEach(0..<10, id: \.self) { _ in
                            Rectangle().frame(height: 1)
                            Spacer().frame(height: 1)
                        }
                    }
                )
                .accessibilityHidden(true)
        case .crosshatch:
            Rectangle()
                .fill(color)
                .overlay(
                    Path { path in
                        for i in stride(from: 0, to: 100, by: 4) {
                            path.move(to: CGPoint(x: i, y: 0))
                            path.addLine(to: CGPoint(x: i, y: 100))
                            path.move(to: CGPoint(x: 0, y: i))
                            path.addLine(to: CGPoint(x: 100, y: i))
                        }
                    }
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
                .accessibilityHidden(true)
        case .solid:
            Rectangle()
                .fill(color)
                .accessibilityHidden(true)
        }
    }
}