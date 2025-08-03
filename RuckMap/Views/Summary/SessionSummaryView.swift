import SwiftUI
import SwiftData
import MapKit
import Speech
import AVFoundation

@Observable
class SessionSummaryViewModel {
    var rpe: Int = 5
    var notes: String = ""
    var voiceNoteURL: URL?
    var isRecording = false
    var showingDeleteConfirmation = false
    var showingSaveConfirmation = false
    var isSaving = false
    var showingShareSheet = false
    var shareURL: URL?
    var saveError: Error?
    
    // Voice recording properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    init() {
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = nil
    }
    
    func startVoiceRecording() async throws {
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            throw VoiceRecordingError.speechRecognizerUnavailable
        }
        
        // Request authorization
        let authStatus = await SFSpeechRecognizer.requestAuthorization()
        guard authStatus == .authorized else {
            throw VoiceRecordingError.authorizationDenied
        }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecordingError.recognitionRequestFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        
        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.notes = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    self?.stopVoiceRecording()
                }
            }
        }
    }
    
    func stopVoiceRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
    }
    
    func saveSession(_ session: RuckSession, modelContext: ModelContext) async throws {
        isSaving = true
        defer { isSaving = false }
        
        // Update session with summary data
        session.rpe = rpe
        session.notes = notes.isEmpty ? nil : notes
        session.voiceNoteURL = voiceNoteURL
        session.updateModificationDate()
        
        // End the session if not already ended
        if session.endDate == nil {
            session.endDate = Date()
        }
        
        // Save to context
        try modelContext.save()
    }
    
    func deleteSession(_ session: RuckSession, modelContext: ModelContext) async throws {
        modelContext.delete(session)
        try modelContext.save()
    }
    
    func shareSession(_ session: RuckSession, dataCoordinator: DataCoordinator) async throws {
        let shareManager = ShareManager()
        shareURL = try await dataCoordinator.exportSession(sessionId: session.id, format: .gpx)
        showingShareSheet = true
    }
}

enum VoiceRecordingError: LocalizedError {
    case speechRecognizerUnavailable
    case authorizationDenied
    case recognitionRequestFailed
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available on this device"
        case .authorizationDenied:
            return "Speech recognition permission denied"
        case .recognitionRequestFailed:
            return "Failed to create speech recognition request"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}

struct SessionSummaryView: View {
    let session: RuckSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataCoordinator: DataCoordinator
    @State private var viewModel = SessionSummaryViewModel()
    @AppStorage("preferredUnits") private var preferredUnits = "imperial"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Session Header
                    sessionHeaderSection
                    
                    // Comprehensive Statistics
                    statisticsSection
                    
                    // Weather Conditions
                    if let weather = session.weatherConditions {
                        weatherSection(weather)
                    }
                    
                    // Route Visualization
                    if !session.locationPoints.isEmpty {
                        routeVisualizationSection
                    }
                    
                    // RPE Input Section
                    rpeInputSection
                    
                    // Notes Section
                    notesSection
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Save Session", isPresented: $viewModel.showingSaveConfirmation) {
                Button("Save") {
                    Task {
                        await saveSession()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Save this ruck session with your notes and rating?")
            }
            .alert("Delete Session", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSession()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(viewModel.saveError != nil)) {
                Button("OK") { viewModel.saveError = nil }
            } message: {
                Text(viewModel.saveError?.localizedDescription ?? "Unknown error")
            }
            .sheet(isPresented: $viewModel.showingShareSheet) {
                if let url = viewModel.shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var sessionHeaderSection: some View {
        VStack(spacing: 16) {
            // Session completion badge
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Primary metrics
            HStack(spacing: 20) {
                MetricPill(
                    title: "Distance",
                    value: FormatUtilities.formatDistancePrecise(session.totalDistance),
                    icon: "location.fill",
                    color: .blue
                )
                
                MetricPill(
                    title: "Duration",
                    value: FormatUtilities.formatDurationWithSeconds(session.duration),
                    icon: "clock.fill",
                    color: .green
                )
                
                MetricPill(
                    title: "Load",
                    value: FormatUtilities.formatWeight(session.loadWeight),
                    icon: "backpack.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.liquidGlassCard)
        .cornerRadius(16)
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Performance metrics
                StatisticCard(
                    title: "Average Pace",
                    value: formatPace(session.averagePace),
                    subtitle: "per mile",
                    icon: "speedometer",
                    color: .blue
                )
                
                StatisticCard(
                    title: "Calories Burned",
                    value: "\(Int(session.totalCalories))",
                    subtitle: "total",
                    icon: "flame.fill",
                    color: .red
                )
                
                StatisticCard(
                    title: "Elevation Gain",
                    value: "\(Int(session.elevationGain))m",
                    subtitle: "↗ ascent",
                    icon: "arrow.up.forward",
                    color: .green
                )
                
                StatisticCard(
                    title: "Elevation Loss",
                    value: "\(Int(session.elevationLoss))m",
                    subtitle: "↘ descent",
                    icon: "arrow.down.forward",
                    color: .purple
                )
                
                StatisticCard(
                    title: "Average Grade",
                    value: String(format: "%.1f%%", session.averageGrade),
                    subtitle: "incline",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
                
                StatisticCard(
                    title: "Data Points",
                    value: "\(session.locationPoints.count)",
                    subtitle: "GPS fixes",
                    icon: "location.circle.fill",
                    color: .teal
                )
            }
            
            // Terrain breakdown if available
            if !session.terrainSegments.isEmpty {
                terrainBreakdownSection
            }
        }
    }
    
    private var terrainBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terrain Analysis")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(Set(session.terrainSegments.map(\.terrainType))), id: \.rawValue) { terrainType in
                    let segments = session.terrainSegments.filter { $0.terrainType == terrainType }
                    let totalDuration = segments.reduce(0) { $0 + $1.duration }
                    let percentage = totalDuration / session.duration * 100
                    
                    TerrainPill(
                        type: terrainType,
                        percentage: percentage
                    )
                }
            }
        }
        .padding()
        .background(Color.ruckMapTertiaryBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Weather Section
    
    private func weatherSection(_ weather: WeatherConditions) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather Conditions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: weatherIcon(for: weather))
                        .font(.title2)
                        .foregroundStyle(Color.temperatureColor(for: weather.temperature))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weather.weatherDescription?.capitalized ?? "Clear")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Recorded at \(weather.timestamp.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if weather.isHarshConditions {
                        Label("Harsh", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                HStack(spacing: 16) {
                    WeatherMetric(
                        title: "Temperature",
                        value: "\(Int(weather.temperatureFahrenheit))°F",
                        subtitle: "feels like \(Int(weather.apparentTemperature * 9/5 + 32))°F",
                        icon: "thermometer",
                        color: Color.temperatureColor(for: weather.temperature)
                    )
                    
                    WeatherMetric(
                        title: "Humidity",
                        value: "\(Int(weather.humidity))%",
                        subtitle: "relative",
                        icon: "humidity.fill",
                        color: .blue
                    )
                    
                    WeatherMetric(
                        title: "Wind",
                        value: "\(Int(weather.windSpeedMPH)) mph",
                        subtitle: "\(Int(weather.windDirection))°",
                        icon: "wind",
                        color: .gray
                    )
                }
                
                // Calorie impact
                if weather.temperatureAdjustmentFactor != 1.0 {
                    let impact = Int((weather.temperatureAdjustmentFactor - 1.0) * 100)
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        
                        Text("Weather increased calorie burn by")
                        
                        Text("\(abs(impact))%")
                            .fontWeight(.semibold)
                            .foregroundStyle(impact > 0 ? .orange : .green)
                        
                        Spacer()
                    }
                    .font(.caption)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.liquidGlassCard)
        .cornerRadius(16)
    }
    
    // MARK: - Route Visualization
    
    private var routeVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Route Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: RouteDetailView(session: session)) {
                    Text("View Full Map")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            // Route preview map
            RoutePreviewMap(session: session)
                .frame(height: 200)
                .cornerRadius(12)
                .accessibilityLabel("Route preview showing \(FormatUtilities.formatDistancePrecise(session.totalDistance)) path")
        }
        .padding()
        .background(Color.liquidGlassCard)
        .cornerRadius(16)
    }
    
    // MARK: - RPE Input Section
    
    private var rpeInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rate of Perceived Exertion")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("How hard did this ruck feel? Rate from 1 (very easy) to 10 (maximum effort)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // RPE Visual Scale
            VStack(spacing: 12) {
                HStack {
                    ForEach(1...10, id: \.self) { value in
                        Button(action: { viewModel.rpe = value }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(rpeColor(for: value))
                                    .frame(width: viewModel.rpe == value ? 36 : 28, height: viewModel.rpe == value ? 36 : 28)
                                    .overlay(
                                        Text("\(value)")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    )
                                    .scaleEffect(viewModel.rpe == value ? 1.1 : 1.0)
                                
                                if viewModel.rpe == value {
                                    Text(rpeDescription(for: value))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 50)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("RPE \(value): \(rpeDescription(for: value))")
                        .accessibilityAddTraits(viewModel.rpe == value ? .isSelected : [])
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.rpe)
                
                // Selected RPE description
                Text("Selected: \(viewModel.rpe) - \(rpeDescription(for: viewModel.rpe))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(rpeColor(for: viewModel.rpe))
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.liquidGlassCard)
        .cornerRadius(16)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Session Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Voice input button
                Button(action: toggleVoiceRecording) {
                    Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundStyle(viewModel.isRecording ? .red : .blue)
                        .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                }
                .accessibilityLabel(viewModel.isRecording ? "Stop voice recording" : "Start voice recording")
                .disabled(viewModel.isSaving)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add notes about your ruck session...", text: $viewModel.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(5, reservesSpace: true)
                    .accessibilityLabel("Session notes")
                
                HStack {
                    if viewModel.isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(viewModel.isRecording ? 1.0 : 0.5)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isRecording)
                            
                            Text("Recording...")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(viewModel.notes.count)/500")
                        .font(.caption)
                        .foregroundStyle(viewModel.notes.count > 450 ? .orange : .secondary)
                }
            }
        }
        .padding()
        .background(Color.liquidGlassCard)
        .cornerRadius(16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Save Session Button
            Button(action: { viewModel.showingSaveConfirmation = true }) {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    
                    Text(viewModel.isSaving ? "Saving..." : "Save Session")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.armyGreenPrimary)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isSaving)
            .accessibilityLabel("Save ruck session with RPE \(viewModel.rpe) and notes")
            
            HStack(spacing: 12) {
                // Share Button
                Button(action: shareSession) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSaving)
                
                // Delete Button
                Button(action: { viewModel.showingDeleteConfirmation = true }) {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .disabled(viewModel.isSaving)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleVoiceRecording() {
        if viewModel.isRecording {
            viewModel.stopVoiceRecording()
        } else {
            Task {
                do {
                    try await viewModel.startVoiceRecording()
                } catch {
                    viewModel.saveError = error
                }
            }
        }
    }
    
    private func saveSession() async {
        do {
            try await viewModel.saveSession(session, modelContext: modelContext)
            dismiss()
        } catch {
            viewModel.saveError = error
        }
    }
    
    private func deleteSession() async {
        do {
            try await viewModel.deleteSession(session, modelContext: modelContext)
            dismiss()
        } catch {
            viewModel.saveError = error
        }
    }
    
    private func shareSession() {
        Task {
            do {
                try await viewModel.shareSession(session, dataCoordinator: dataCoordinator)
            } catch {
                viewModel.saveError = error
            }
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func rpeColor(for value: Int) -> Color {
        switch value {
        case 1...2: return .green
        case 3...4: return .yellow
        case 5...6: return .orange
        case 7...8: return .red
        case 9...10: return .purple
        default: return .gray
        }
    }
    
    private func rpeDescription(for value: Int) -> String {
        switch value {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Light"
        case 4: return "Moderate"
        case 5: return "Somewhat Hard"
        case 6: return "Hard"
        case 7: return "Very Hard"
        case 8: return "Extremely Hard"
        case 9: return "Maximum"
        case 10: return "Absolute Max"
        default: return "Unknown"
        }
    }
    
    private func weatherIcon(for weather: WeatherConditions) -> String {
        if weather.precipitation > 0 {
            return "cloud.rain.fill"
        } else if weather.windSpeed > 10 {
            return "wind"
        } else if weather.temperature < 0 {
            return "snowflake"
        } else if weather.temperature > 30 {
            return "sun.max.fill"
        } else {
            return "cloud.sun.fill"
        }
    }
}

// MARK: - Supporting Views

private struct MetricPill: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.ruckMapTertiaryBackground)
        .cornerRadius(8)
    }
}

private struct StatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.ruckMapSecondaryBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(subtitle)")
    }
}

private struct TerrainPill: View {
    let type: TerrainType
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(String(format: "%.0f%%", percentage))
                .font(.caption2)
                .fontWeight(.medium)
            
            Text(type.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(Color.ruckMapTertiaryBackground)
        .cornerRadius(8)
    }
}

private struct WeatherMetric: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.ruckMapTertiaryBackground)
        .cornerRadius(8)
    }
}

private struct RoutePreviewMap: View {
    let session: RuckSession
    
    private var mapRegion: MKCoordinateRegion {
        guard !session.locationPoints.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        let coordinates = session.locationPoints.map { 
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
        }
        
        let minLat = coordinates.min { $0.latitude < $1.latitude }?.latitude ?? 0
        let maxLat = coordinates.max { $0.latitude < $1.latitude }?.latitude ?? 0
        let minLon = coordinates.min { $0.longitude < $1.longitude }?.longitude ?? 0
        let maxLon = coordinates.max { $0.longitude < $1.longitude }?.longitude ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.001, (maxLat - minLat) * 1.2),
            longitudeDelta: max(0.001, (maxLon - minLon) * 1.2)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    var body: some View {
        Map(initialPosition: .region(mapRegion)) {
            if !session.locationPoints.isEmpty {
                MapPolyline(coordinates: session.locationPoints.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(Color.armyGreenPrimary, lineWidth: 3)
                
                // Start marker
                if let firstPoint = session.locationPoints.first {
                    Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: firstPoint.latitude, longitude: firstPoint.longitude)) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                    }
                }
                
                // End marker
                if let lastPoint = session.locationPoints.last {
                    Annotation("End", coordinate: CLLocationCoordinate2D(latitude: lastPoint.latitude, longitude: lastPoint.longitude)) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .disabled(true)
    }
}

private struct RouteDetailView: View {
    let session: RuckSession
    
    var body: some View {
        RoutePreviewMap(session: session)
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// ShareSheet is already defined in SessionDetailView.swift, but including it here for completeness
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: RuckSession.self, configurations: config)
    
    let session = RuckSession()
    session.totalDistance = 5000 // 5km
    session.totalDuration = 3600 // 1 hour
    session.loadWeight = 20 // 20kg
    session.totalCalories = 500
    session.elevationGain = 100
    session.elevationLoss = 80
    session.averageGrade = 5.0
    session.endDate = Date()
    
    // Add some sample location points
    for i in 0..<10 {
        let point = LocationPoint(
            timestamp: Date().addingTimeInterval(TimeInterval(i * 60)),
            latitude: 37.7749 + Double(i) * 0.001,
            longitude: -122.4194 + Double(i) * 0.001,
            altitude: 100 + Double(i) * 10,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            speed: 1.0,
            course: 0.0
        )
        session.locationPoints.append(point)
    }
    
    container.mainContext.insert(session)
    
    return SessionSummaryView(session: session)
        .modelContainer(container)
        .environmentObject(try! DataCoordinator())
}