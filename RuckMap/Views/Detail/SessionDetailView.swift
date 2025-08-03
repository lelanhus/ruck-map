import SwiftUI
import SwiftData
import MapKit
import Charts
import CoreLocation
import Observation

/// Immersive full-screen session detail view with route replay functionality
/// 
/// Features:
/// - Full-screen map experience with route visualization
/// - Color-coded segments by terrain type  
/// - Route replay with play/pause controls and speed controls
/// - Interactive timeline scrubber for manual navigation
/// - Expandable bottom sheet with detailed statistics
/// - Charts for pace, elevation, heart rate over time
/// - Terrain breakdown visualization
/// - Export and sharing capabilities
/// - iOS 26 Liquid Glass preparation
@MainActor
struct DetailedSessionView: View {
    let session: RuckSession
    @State private var detailPresentation = SessionDetailPresentation()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataCoordinator: DataCoordinator
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen map background
                sessionMapView(geometry: geometry)
                
                // Top controls bar
                topControlsBar
                
                // Route replay controls
                if detailPresentation.isReplayMode {
                    replayControlsOverlay
                }
                
                // Bottom sheet with statistics
                bottomSheetOverlay(geometry: geometry)
                
                // Export/share action sheet
                if detailPresentation.showingActionSheet {
                    actionSheetOverlay
                }
            }
            .ignoresSafeArea(edges: detailPresentation.isFullScreen ? .all : .bottom)
        }
        .navigationBarHidden(true)
        .task {
            await detailPresentation.initialize(with: session)
        }
        .onChange(of: detailPresentation.replayProgress) { _, _ in
            detailPresentation.updateReplayPosition()
        }
    }
    
    // MARK: - Map View
    
    private func sessionMapView(geometry: GeometryProxy) -> some View {
        Map(
            position: $detailPresentation.cameraPosition,
            bounds: detailPresentation.mapBounds,
            interactionModes: detailPresentation.mapInteractionModes
        ) {
            // Main route polyline with terrain-based coloring
            ForEach(detailPresentation.terrainSegmentPolylines, id: \.id) { segment in
                MapPolyline(segment.polyline)
                    .stroke(
                        segment.terrainColor,
                        style: StrokeStyle(
                            lineWidth: 6.0,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
            
            // Start marker
            if let startCoordinate = detailPresentation.startCoordinate {
                Annotation("Start", coordinate: startCoordinate, anchor: .center) {
                    RouteMarker(
                        type: .start,
                        title: "Start",
                        subtitle: detailPresentation.startTimeText
                    )
                }
            }
            
            // End marker  
            if let endCoordinate = detailPresentation.endCoordinate {
                Annotation("Finish", coordinate: endCoordinate, anchor: .center) {
                    RouteMarker(
                        type: .end,
                        title: "Finish",
                        subtitle: detailPresentation.endTimeText
                    )
                }
            }
            
            // Mile/kilometer markers
            ForEach(detailPresentation.distanceMarkers, id: \.id) { marker in
                Annotation(marker.title, coordinate: marker.coordinate, anchor: .center) {
                    DistanceMarker(
                        distance: marker.distance,
                        units: detailPresentation.units,
                        splitTime: marker.splitTime
                    )
                }
            }
            
            // Current replay position
            if detailPresentation.isReplayMode,
               let replayPosition = detailPresentation.currentReplayPosition {
                Annotation("Current Position", coordinate: replayPosition.coordinate, anchor: .center) {
                    ReplayPositionMarker(
                        isAnimating: detailPresentation.isReplaying,
                        heading: replayPosition.course
                    )
                }
            }
            
            // Interactive route points for detailed stats
            if detailPresentation.showDetailedPoints {
                ForEach(detailPresentation.interactivePoints, id: \.id) { point in
                    Annotation("", coordinate: point.coordinate, anchor: .center) {
                        InteractiveRoutePoint(
                            point: point,
                            isSelected: detailPresentation.selectedPointId == point.id
                        ) {
                            detailPresentation.selectPoint(point)
                        }
                    }
                }
            }
            
            // Photo annotations
            ForEach(detailPresentation.photoAnnotations, id: \.id) { photo in
                Annotation("Photo", coordinate: photo.coordinate, anchor: .center) {
                    PhotoAnnotation(photo: photo) {
                        detailPresentation.showPhoto(photo)
                    }
                }
            }
        }
        .mapStyle(detailPresentation.currentMapStyle)
        .mapControlVisibility(.hidden)
        .onTapGesture(coordinateSpace: .local) { location in
            detailPresentation.handleMapTap(at: location, in: geometry)
        }
        .accessibilityLabel("Session route map")
        .accessibilityHint("Shows the complete route with terrain segments and markers")
    }
    
    // MARK: - Top Controls
    
    private var topControlsBar: some View {
        VStack {
            HStack {
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Back")
                
                Spacer()
                
                // Session title and date
                if !detailPresentation.isFullScreen {
                    VStack(alignment: .center, spacing: 2) {
                        Text(detailPresentation.sessionTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(detailPresentation.sessionDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // Map style toggle
                    Button(action: detailPresentation.toggleMapStyle) {
                        Image(systemName: detailPresentation.mapStyleIcon)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("Change map style")
                    
                    // Fullscreen toggle
                    Button(action: detailPresentation.toggleFullScreen) {
                        Image(systemName: detailPresentation.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel(detailPresentation.isFullScreen ? "Exit fullscreen" : "Enter fullscreen")
                    
                    // More actions
                    Button(action: { detailPresentation.showingActionSheet = true }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("More actions")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Replay Controls
    
    private var replayControlsOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Timeline scrubber
                timelineScrubber
                
                // Playback controls
                HStack(spacing: 24) {
                    // Speed control
                    Button(action: detailPresentation.cycleReplaySpeed) {
                        Text("\(detailPresentation.replaySpeed, specifier: "%.0f")x")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .accessibilityLabel("Replay speed: \(detailPresentation.replaySpeed)x")
                    
                    // Previous waypoint
                    Button(action: detailPresentation.previousWaypoint) {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                            .foregroundColor(detailPresentation.canGoPrevious ? .primary : .secondary)
                    }
                    .disabled(!detailPresentation.canGoPrevious)
                    .accessibilityLabel("Previous waypoint")
                    
                    // Play/pause
                    Button(action: detailPresentation.toggleReplay) {
                        Image(systemName: detailPresentation.isReplaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.primary)
                            .padding(16)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel(detailPresentation.isReplaying ? "Pause replay" : "Start replay")
                    
                    // Next waypoint
                    Button(action: detailPresentation.nextWaypoint) {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                            .foregroundColor(detailPresentation.canGoNext ? .primary : .secondary)
                    }
                    .disabled(!detailPresentation.canGoNext)
                    .accessibilityLabel("Next waypoint")
                    
                    // Stop replay
                    Button(action: detailPresentation.stopReplay) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Stop replay")
                }
                
                // Current position info
                if let currentStats = detailPresentation.currentReplayStats {
                    HStack(spacing: 20) {
                        replayStatItem("Time", currentStats.timeText)
                        replayStatItem("Distance", currentStats.distanceText)
                        replayStatItem("Pace", currentStats.paceText)
                        replayStatItem("Elevation", currentStats.elevationText)
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, detailPresentation.isFullScreen ? 50 : 20)
        }
    }
    
    private var timelineScrubber: some View {
        VStack(spacing: 8) {
            // Time labels
            HStack {
                Text(detailPresentation.startTimeText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if detailPresentation.isReplaying {
                    Text(detailPresentation.currentReplayTimeText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(detailPresentation.endTimeText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Progress slider
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(height: 8)
                
                // Progress fill with terrain colors
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(detailPresentation.timelineSegments, id: \.id) { segment in
                            Rectangle()
                                .fill(segment.color)
                                .frame(width: geometry.size.width * segment.relativeWidth)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 8)
                
                // Current position indicator
                Circle()
                    .fill(.primary)
                    .frame(width: 16, height: 16)
                    .offset(x: detailPresentation.scrubberOffset - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                detailPresentation.handleScrubberDrag(value)
                            }
                    )
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Bottom Sheet
    
    private func bottomSheetOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            
            BottomSheet(
                isExpanded: $detailPresentation.isBottomSheetExpanded,
                maxHeight: geometry.size.height * 0.7
            ) {
                sessionStatisticsContent
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var sessionStatisticsContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Sheet handle and header
                sheetHeader
                
                // Quick stats overview
                quickStatsGrid
                
                // Charts section
                chartsSection
                
                // Terrain breakdown
                terrainBreakdownSection
                
                // Split times
                splitTimesSection
                
                // Weather information
                if let weatherConditions = session.weatherConditions {
                    weatherSection(weatherConditions)
                }
                
                // Photos section
                if !detailPresentation.photoAnnotations.isEmpty {
                    photosSection
                }
                
                // Notes and RPE
                notesSection
                
                // Equipment information
                equipmentSection
                
                // Export and sharing
                exportSection
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Sheet Components
    
    private var sheetHeader: some View {
        VStack(spacing: 8) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(.tertiary)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            // Title and controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Statistics")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(detailPresentation.sessionSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Replay toggle
                Button(action: detailPresentation.toggleReplayMode) {
                    Image(systemName: detailPresentation.isReplayMode ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.armyGreenPrimary)
                }
                .accessibilityLabel(detailPresentation.isReplayMode ? "Stop replay mode" : "Start replay mode")
            }
            .padding(.horizontal)
        }
    }
    
    private var quickStatsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
            spacing: 12
        ) {
            StatCard(
                title: "Total Distance",
                value: detailPresentation.formattedDistance,
                icon: "location.fill",
                color: .blue
            )
            
            StatCard(
                title: "Duration",
                value: detailPresentation.formattedDuration,
                icon: "clock.fill",
                color: .orange
            )
            
            StatCard(
                title: "Average Pace",
                value: detailPresentation.formattedAveragePace,
                icon: "speedometer",
                color: .green
            )
            
            StatCard(
                title: "Calories",
                value: detailPresentation.formattedCalories,
                icon: "flame.fill",
                color: .red
            )
            
            StatCard(
                title: "Elevation Gain",
                value: detailPresentation.formattedElevationGain,
                icon: "arrow.up.forward",
                color: .purple
            )
            
            StatCard(
                title: "Load Weight",
                value: detailPresentation.formattedLoadWeight,
                icon: "backpack.fill",
                color: .brown
            )
        }
    }
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Charts")
                .font(.headline)
                .padding(.horizontal)
            
            TabView(selection: $detailPresentation.selectedChartTab) {
                // Pace chart
                paceChart
                    .tag(0)
                
                // Elevation chart  
                elevationChart
                    .tag(1)
                
                // Heart rate chart (if available)
                if detailPresentation.hasHeartRateData {
                    heartRateChart
                        .tag(2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 250)
            
            // Chart selector
            chartTabSelector
        }
    }
    
    // MARK: - Charts
    
    private var paceChart: some View {
        Chart {
            ForEach(detailPresentation.paceDataPoints, id: \.id) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Pace", point.pace)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
            }
            
            // Add terrain background areas
            ForEach(detailPresentation.terrainChartSegments, id: \.id) { segment in
                RectangleMark(
                    xStart: .value("Start", segment.startTime),
                    xEnd: .value("End", segment.endTime),
                    yStart: .value("Min", detailPresentation.minPace),
                    yEnd: .value("Max", detailPresentation.maxPace)
                )
                .foregroundStyle(segment.color.opacity(0.2))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(detailPresentation.formatChartTime(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let pace = value.as(Double.self) {
                        Text(detailPresentation.formatPace(pace))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 200)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
            Text("Pace Over Time")
                .font(.caption)
                .fontWeight(.medium)
                .padding(8)
        }
    }
    
    private var elevationChart: some View {
        Chart {
            // Elevation area
            ForEach(detailPresentation.elevationDataPoints, id: \.id) { point in
                AreaMark(
                    x: .value("Time", point.time),
                    yStart: .value("Base", detailPresentation.baseElevation),
                    yEnd: .value("Elevation", point.elevation)
                )
                .foregroundStyle(.green.opacity(0.3))
                
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Elevation", point.elevation)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(detailPresentation.formatChartTime(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let elevation = value.as(Double.self) {
                        Text("\(Int(elevation))m")
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 200)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
            Text("Elevation Profile")
                .font(.caption)
                .fontWeight(.medium)
                .padding(8)
        }
    }
    
    private var heartRateChart: some View {
        Chart {
            ForEach(detailPresentation.heartRateDataPoints, id: \.id) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Heart Rate", point.heartRate)
                )
                .foregroundStyle(.red)
                .interpolationMethod(.catmullRom)
            }
            
            // Heart rate zones
            RectangleMark(
                xStart: .value("Start", detailPresentation.chartStartTime),
                xEnd: .value("End", detailPresentation.chartEndTime),
                yStart: .value("Zone Start", 120),
                yEnd: .value("Zone End", 140)
            )
            .foregroundStyle(.orange.opacity(0.1))
        }
        .frame(height: 200)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
            Text("Heart Rate")
                .font(.caption)
                .fontWeight(.medium)
                .padding(8)
        }
    }
    
    private var chartTabSelector: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 8) {
                chartTabButton("Pace", 0)
                chartTabButton("Elevation", 1)
                
                if detailPresentation.hasHeartRateData {
                    chartTabButton("Heart Rate", 2)
                }
            }
            .padding(4)
            .background(.quaternary, in: Capsule())
            
            Spacer()
        }
    }
    
    private func chartTabButton(_ title: String, _ tag: Int) -> some View {
        Button(action: { detailPresentation.selectedChartTab = tag }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(detailPresentation.selectedChartTab == tag ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    detailPresentation.selectedChartTab == tag ? .armyGreenPrimary : .clear,
                    in: Capsule()
                )
        }
        .accessibilityLabel("\(title) chart")
        .accessibilityAddTraits(detailPresentation.selectedChartTab == tag ? .isSelected : [])
    }
    
    // MARK: - Terrain Breakdown
    
    private var terrainBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Terrain Breakdown")
                .font(.headline)
            
            // Terrain pie chart
            Chart {
                ForEach(detailPresentation.terrainBreakdown, id: \.terrain) { data in
                    SectorMark(
                        angle: .value("Percentage", data.percentage),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(data.color)
                    .opacity(0.8)
                }
            }
            .frame(height: 200)
            
            // Terrain legend
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(detailPresentation.terrainBreakdown, id: \.terrain) { data in
                    HStack {
                        Circle()
                            .fill(data.color)
                            .frame(width: 12, height: 12)
                        
                        Text(data.terrain.displayName)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(data.percentage, specifier: "%.1f")%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Additional Sections
    
    private var splitTimesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Split Times")
                .font(.headline)
            
            ForEach(detailPresentation.splitTimes, id: \.distance) { split in
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(split.distance, specifier: "%.1f") \(detailPresentation.units)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Pace: \(split.paceText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(split.timeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func weatherSection(_ weather: WeatherConditions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weather Conditions")
                .font(.headline)
            
            HStack {
                Image(systemName: "cloud.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(weather.weatherDescription?.capitalized ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("During session")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                weatherMetric("Temperature", "\(Int(weather.temperatureFahrenheit))°F", "thermometer")
                weatherMetric("Humidity", "\(Int(weather.humidity))%", "humidity")
                weatherMetric("Wind", "\(Int(weather.windSpeedMPH)) mph", "wind")
            }
            
            if weather.temperatureAdjustmentFactor != 1.0 {
                let impact = Int((weather.temperatureAdjustmentFactor - 1.0) * 100)
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    
                    Text("Weather Impact on Calories:")
                    
                    Spacer()
                    
                    Text("\(impact >= 0 ? "+" : "")\(impact)%")
                        .fontWeight(.medium)
                        .foregroundColor(impact > 0 ? .orange : .green)
                }
                .font(.caption)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(detailPresentation.photoAnnotations, id: \.id) { photo in
                        AsyncImage(url: photo.imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(.quaternary)
                                .overlay {
                                    ProgressView()
                                }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            detailPresentation.showPhoto(photo)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes & RPE")
                .font(.headline)
            
            if let rpe = session.rpe {
                HStack {
                    Text("Rating of Perceived Exertion:")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(rpe)/10")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.armyGreenPrimary)
                }
            }
            
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No notes recorded")
                    .font(.body)
                    .foregroundColor(.tertiary)
                    .italic()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Equipment")
                .font(.headline)
            
            HStack {
                Image(systemName: "backpack.fill")
                    .foregroundColor(.brown)
                
                Text("Load Weight:")
                
                Spacer()
                
                Text("\(session.loadWeight, specifier: "%.1f") kg")
                    .fontWeight(.medium)
            }
            
            // Add more equipment details here if available
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var exportSection: some View {
        VStack(spacing: 12) {
            Text("Export & Share")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: detailPresentation.exportSession) {
                    Label("Export GPX", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.armyGreenPrimary)
                
                Button(action: detailPresentation.shareSession) {
                    Label("Share", systemImage: "square.and.arrow.up.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            HStack(spacing: 12) {
                Button(action: detailPresentation.printSummary) {
                    Label("Print Summary", systemImage: "printer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: detailPresentation.saveRoute) {
                    Label("Save Route", systemImage: "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Action Sheet
    
    private var actionSheetOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    detailPresentation.showingActionSheet = false
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    actionSheetButton("Export GPX", "square.and.arrow.up", detailPresentation.exportSession)
                    actionSheetButton("Share Session", "square.and.arrow.up.on.square", detailPresentation.shareSession)
                    actionSheetButton("Print Summary", "printer", detailPresentation.printSummary)
                    actionSheetButton("Save Route Template", "bookmark", detailPresentation.saveRoute)
                    
                    Button(action: { detailPresentation.showingActionSheet = false }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(.regularMaterial)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func replayStatItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private func weatherMetric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private func actionSheetButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            .foregroundColor(.primary)
            .padding()
        }
        .background(.regularMaterial)
    }
}

// MARK: - Session Detail Presentation

/// @Observable state manager for session detail view
/// Handles route replay, map interaction, and statistics presentation
@MainActor
@Observable
final class SessionDetailPresentation {
    
    // MARK: - Session Data
    
    private(set) var session: RuckSession?
    
    // MARK: - Map State
    
    var cameraPosition: MapCameraPosition = .automatic
    var mapBounds: MapCameraBounds?
    var currentMapStyle: MapStyle = .standard(elevation: .realistic)
    var mapInteractionModes: MapInteractionModes = .all
    
    var isFullScreen = false
    var showingActionSheet = false
    var isBottomSheetExpanded = false
    
    // MARK: - Route Visualization
    
    private(set) var terrainSegmentPolylines: [TerrainSegmentPolyline] = []
    private(set) var startCoordinate: CLLocationCoordinate2D?
    private(set) var endCoordinate: CLLocationCoordinate2D?
    private(set) var distanceMarkers: [DistanceMarkerData] = []
    private(set) var photoAnnotations: [PhotoAnnotationData] = []
    private(set) var interactivePoints: [InteractiveRoutePointData] = []
    
    var showDetailedPoints = false
    var selectedPointId: UUID?
    
    // MARK: - Replay State
    
    var isReplayMode = false
    var isReplaying = false
    var replayProgress: Double = 0.0
    var replaySpeed: Double = 1.0
    private(set) var currentReplayPosition: LocationPoint?
    private(set) var currentReplayStats: ReplayStats?
    
    var canGoPrevious: Bool { replayProgress > 0 }
    var canGoNext: Bool { replayProgress < 1.0 }
    var scrubberOffset: CGFloat = 0
    
    // MARK: - Timeline Visualization
    
    private(set) var timelineSegments: [TimelineSegment] = []
    
    // MARK: - Charts Data
    
    var selectedChartTab = 0
    private(set) var paceDataPoints: [PaceDataPoint] = []
    private(set) var elevationDataPoints: [ElevationDataPoint] = []
    private(set) var heartRateDataPoints: [HeartRateDataPoint] = []
    private(set) var terrainChartSegments: [TerrainChartSegment] = []
    
    var hasHeartRateData: Bool { !heartRateDataPoints.isEmpty }
    var minPace: Double = 0
    var maxPace: Double = 0
    var baseElevation: Double = 0
    var chartStartTime: Date = Date()
    var chartEndTime: Date = Date()
    
    // MARK: - Statistics
    
    private(set) var terrainBreakdown: [TerrainBreakdownData] = []
    private(set) var splitTimes: [SplitTimeData] = []
    
    // MARK: - Display Properties
    
    var units = "km"
    var sessionTitle = ""
    var sessionDate = ""
    var sessionSummary = ""
    var startTimeText = ""
    var endTimeText = ""
    var currentReplayTimeText = ""
    
    var formattedDistance = ""
    var formattedDuration = ""
    var formattedAveragePace = ""
    var formattedCalories = ""
    var formattedElevationGain = ""
    var formattedLoadWeight = ""
    
    var mapStyleIcon: String {
        switch currentMapStyle {
        case .standard: return "map"
        case .hybrid: return "map.fill"
        case .imagery: return "globe.americas"
        default: return "map"
        }
    }
    
    // MARK: - Performance Optimization
    
    private var replayTimer: Timer?
    private var lastUpdateTime: Date = Date()
    private let updateThrottle: TimeInterval = 1.0/30.0 // 30fps max
    
    // MARK: - Initialization
    
    func initialize(with session: RuckSession) async {
        self.session = session
        
        await MainActor.run {
            setupBasicProperties()
            generateTerrainSegmentPolylines()
            generateDistanceMarkers()
            generateInteractivePoints()
            generateChartData()
            generateStatistics()
            setupMapBounds()
        }
    }
    
    private func setupBasicProperties() {
        guard let session = session else { return }
        
        sessionTitle = "Ruck Session"
        sessionDate = DateFormatter.localizedString(from: session.startDate, dateStyle: .medium, timeStyle: .short)
        sessionSummary = "\(formattedDistance) • \(formattedDuration) • \(formattedCalories)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        startTimeText = dateFormatter.string(from: session.startDate)
        endTimeText = session.endDate.map { dateFormatter.string(from: $0) } ?? ""
        
        // Format display values
        formattedDistance = String(format: "%.2f %@", session.totalDistance / 1000, units)
        formattedDuration = formatDuration(session.duration)
        formattedAveragePace = formatPace(session.averagePace)
        formattedCalories = "\(Int(session.totalCalories))"
        formattedElevationGain = "\(Int(session.elevationGain))m"
        formattedLoadWeight = "\(session.loadWeight, specifier: "%.1f") kg"
        
        chartStartTime = session.startDate
        chartEndTime = session.endDate ?? Date()
    }
    
    // MARK: - Route Visualization Generation
    
    private func generateTerrainSegmentPolylines() {
        guard let session = session else { return }
        
        // Group location points by terrain segments
        let terrainSegments = session.terrainSegments.sorted { $0.startTime < $1.startTime }
        
        for segment in terrainSegments {
            let segmentPoints = session.locationPoints.filter { point in
                point.timestamp >= segment.startTime && point.timestamp <= segment.endTime
            }.sorted { $0.timestamp < $1.timestamp }
            
            guard segmentPoints.count >= 2 else { continue }
            
            let coordinates = segmentPoints.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            
            terrainSegmentPolylines.append(
                TerrainSegmentPolyline(
                    id: UUID(),
                    polyline: polyline,
                    terrainType: segment.terrainType,
                    terrainColor: colorForTerrain(segment.terrainType)
                )
            )
        }
        
        // Set start/end coordinates
        if let firstPoint = session.locationPoints.first {
            startCoordinate = firstPoint.coordinate
        }
        if let lastPoint = session.locationPoints.last {
            endCoordinate = lastPoint.coordinate
        }
    }
    
    private func generateDistanceMarkers() {
        guard let session = session else { return }
        
        let distanceInterval: Double = units == "km" ? 1000 : FormatUtilities.ConversionConstants.metersToMiles // 1km or 1 mile
        var accumulatedDistance: Double = 0
        var markerDistance: Double = distanceInterval
        var lastPoint: LocationPoint?
        
        for point in session.locationPoints.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let previous = lastPoint {
                accumulatedDistance += point.distance(to: previous)
                
                if accumulatedDistance >= markerDistance {
                    let markerNumber = Int(markerDistance / distanceInterval)
                    let splitTime = point.timestamp.timeIntervalSince(session.startDate)
                    
                    distanceMarkers.append(
                        DistanceMarkerData(
                            id: UUID(),
                            coordinate: point.coordinate,
                            distance: Double(markerNumber),
                            title: units == "km" ? "\(markerNumber) km" : "\(markerNumber) mi",
                            splitTime: formatDuration(splitTime)
                        )
                    )
                    
                    markerDistance += distanceInterval
                }
            }
            lastPoint = point
        }
    }
    
    private func generateInteractivePoints() {
        guard let session = session else { return }
        
        // Select representative points for interaction (every ~100 points for performance)
        let totalPoints = session.locationPoints.count
        let targetPoints = min(50, totalPoints / 10) // Max 50 interactive points
        let step = max(1, totalPoints / targetPoints)
        
        for i in stride(from: 0, to: totalPoints, by: step) {
            let point = session.locationPoints[i]
            let elapsedTime = point.timestamp.timeIntervalSince(session.startDate)
            
            interactivePoints.append(
                InteractiveRoutePointData(
                    id: UUID(),
                    coordinate: point.coordinate,
                    timestamp: point.timestamp,
                    elevation: point.bestAltitude,
                    pace: calculateInstantaneousPace(at: i),
                    timeText: formatDuration(elapsedTime),
                    elevationText: "\(Int(point.bestAltitude))m"
                )
            )
        }
    }
    
    private func generateChartData() {
        guard let session = session else { return }
        
        let points = session.locationPoints.sorted { $0.timestamp < $1.timestamp }
        
        // Generate pace data points (sample every minute for performance)
        var lastPaceTime = session.startDate
        let paceInterval: TimeInterval = 60 // 1 minute intervals
        
        for point in points {
            if point.timestamp.timeIntervalSince(lastPaceTime) >= paceInterval {
                let pace = calculateInstantaneousPace(for: point)
                paceDataPoints.append(
                    PaceDataPoint(
                        id: UUID(),
                        time: point.timestamp,
                        pace: pace
                    )
                )
                lastPaceTime = point.timestamp
            }
        }
        
        // Calculate min/max pace for chart scaling
        let paces = paceDataPoints.map { $0.pace }.filter { $0 > 0 }
        minPace = paces.min() ?? 0
        maxPace = paces.max() ?? 0
        
        // Generate elevation data points
        var lastElevationTime = session.startDate
        baseElevation = points.first?.bestAltitude ?? 0
        
        for point in points {
            if point.timestamp.timeIntervalSince(lastElevationTime) >= paceInterval {
                elevationDataPoints.append(
                    ElevationDataPoint(
                        id: UUID(),
                        time: point.timestamp,
                        elevation: point.bestAltitude
                    )
                )
                lastElevationTime = point.timestamp
            }
        }
        
        // Generate heart rate data if available
        for point in points.filter({ $0.heartRate != nil }) {
            heartRateDataPoints.append(
                HeartRateDataPoint(
                    id: UUID(),
                    time: point.timestamp,
                    heartRate: point.heartRate ?? 0
                )
            )
        }
        
        // Generate terrain chart segments
        for segment in session.terrainSegments {
            terrainChartSegments.append(
                TerrainChartSegment(
                    id: UUID(),
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    color: colorForTerrain(segment.terrainType)
                )
            )
        }
    }
    
    private func generateStatistics() {
        guard let session = session else { return }
        
        // Generate terrain breakdown
        let totalDuration = session.duration
        var terrainDurations: [TerrainType: TimeInterval] = [:]
        
        for segment in session.terrainSegments {
            let duration = segment.duration
            terrainDurations[segment.terrainType, default: 0] += duration
        }
        
        terrainBreakdown = terrainDurations.map { terrain, duration in
            TerrainBreakdownData(
                terrain: terrain,
                percentage: (duration / totalDuration) * 100,
                color: colorForTerrain(terrain)
            )
        }.sorted { $0.percentage > $1.percentage }
        
        // Generate split times
        generateSplitTimes()
        
        // Generate timeline segments for replay scrubber
        generateTimelineSegments()
    }
    
    private func generateSplitTimes() {
        guard let session = session else { return }
        
        let distanceInterval: Double = units == "km" ? 1000 : FormatUtilities.ConversionConstants.metersToMiles
        var accumulatedDistance: Double = 0
        var splitDistance: Double = distanceInterval
        var lastPoint: LocationPoint?
        var lastSplitTime = session.startDate
        
        for point in session.locationPoints.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let previous = lastPoint {
                accumulatedDistance += point.distance(to: previous)
                
                if accumulatedDistance >= splitDistance {
                    let splitNumber = Int(splitDistance / distanceInterval)
                    let splitDuration = point.timestamp.timeIntervalSince(lastSplitTime)
                    let pace = splitDuration / 60.0 // minutes per km/mile
                    
                    splitTimes.append(
                        SplitTimeData(
                            distance: Double(splitNumber),
                            timeText: formatDuration(point.timestamp.timeIntervalSince(session.startDate)),
                            paceText: formatPace(pace)
                        )
                    )
                    
                    splitDistance += distanceInterval
                    lastSplitTime = point.timestamp
                }
            }
            lastPoint = point
        }
    }
    
    private func generateTimelineSegments() {
        guard let session = session else { return }
        
        let totalDuration = session.duration
        
        for segment in session.terrainSegments.sorted(by: { $0.startTime < $1.startTime }) {
            let startProgress = segment.startTime.timeIntervalSince(session.startDate) / totalDuration
            let endProgress = segment.endTime.timeIntervalSince(session.startDate) / totalDuration
            let width = endProgress - startProgress
            
            timelineSegments.append(
                TimelineSegment(
                    id: UUID(),
                    relativeWidth: width,
                    color: colorForTerrain(segment.terrainType)
                )
            )
        }
    }
    
    private func setupMapBounds() {
        guard let session = session else { return }
        
        let coordinates = session.locationPoints.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }
        
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2, // Add 20% padding
            longitudeDelta: (maxLon - minLon) * 1.2
        )
        
        mapBounds = MapCameraBounds(
            centerCoordinateBounds: MKMapRect(
                origin: MKMapPoint(CLLocationCoordinate2D(latitude: minLat, longitude: minLon)),
                size: MKMapSize(width: maxLon - minLon, height: maxLat - minLat)
            ),
            minimumDistance: 100,
            maximumDistance: 50000
        )
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
    
    // MARK: - Replay Controls
    
    func toggleReplayMode() {
        isReplayMode.toggle()
        
        if !isReplayMode {
            stopReplay()
        } else {
            setupReplay()
        }
    }
    
    private func setupReplay() {
        replayProgress = 0.0
        updateReplayPosition()
    }
    
    func toggleReplay() {
        isReplaying.toggle()
        
        if isReplaying {
            startReplay()
        } else {
            pauseReplay()
        }
    }
    
    private func startReplay() {
        replayTimer?.invalidate()
        replayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateReplayProgress()
            }
        }
    }
    
    private func pauseReplay() {
        replayTimer?.invalidate()
    }
    
    func stopReplay() {
        isReplaying = false
        replayTimer?.invalidate()
        replayProgress = 0.0
        updateReplayPosition()
    }
    
    func cycleReplaySpeed() {
        switch replaySpeed {
        case 1.0: replaySpeed = 2.0
        case 2.0: replaySpeed = 4.0
        case 4.0: replaySpeed = 8.0
        default: replaySpeed = 1.0
        }
    }
    
    func nextWaypoint() {
        guard let session = session else { return }
        
        let currentIndex = Int(replayProgress * Double(session.locationPoints.count))
        let nextMarkerIndex = distanceMarkers.first { marker in
            // Find next distance marker
            return true // Simplified logic
        }
        
        // Jump to next significant waypoint
        replayProgress = min(1.0, replayProgress + 0.1)
        updateReplayPosition()
    }
    
    func previousWaypoint() {
        replayProgress = max(0.0, replayProgress - 0.1)
        updateReplayPosition()
    }
    
    private func updateReplayProgress() {
        guard let session = session, isReplaying else { return }
        
        let increment = (replaySpeed * 0.1) / session.duration
        replayProgress = min(1.0, replayProgress + increment)
        
        if replayProgress >= 1.0 {
            isReplaying = false
            replayTimer?.invalidate()
        }
        
        updateReplayPosition()
    }
    
    func updateReplayPosition() {
        guard let session = session else { return }
        
        let pointIndex = Int(replayProgress * Double(session.locationPoints.count - 1))
        let clampedIndex = min(max(0, pointIndex), session.locationPoints.count - 1)
        
        currentReplayPosition = session.locationPoints[clampedIndex]
        
        if let position = currentReplayPosition {
            let elapsedTime = position.timestamp.timeIntervalSince(session.startDate)
            let distance = calculateDistanceAtPoint(clampedIndex)
            let pace = calculateInstantaneousPace(at: clampedIndex)
            
            currentReplayStats = ReplayStats(
                timeText: formatDuration(elapsedTime),
                distanceText: String(format: "%.2f %@", distance / 1000, units),
                paceText: formatPace(pace),
                elevationText: "\(Int(position.bestAltitude))m"
            )
            
            currentReplayTimeText = formatDuration(elapsedTime)
            
            // Update camera to follow replay position
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: position.coordinate,
                        distance: 1000,
                        heading: position.course,
                        pitch: 30
                    )
                )
            }
        }
    }
    
    func handleScrubberDrag(_ value: DragGesture.Value) {
        // Update replay progress based on drag gesture
        let progress = value.location.x / value.startLocation.x
        replayProgress = max(0.0, min(1.0, progress))
        updateReplayPosition()
    }
    
    // MARK: - Map Interaction
    
    func toggleMapStyle() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentMapStyle {
            case .standard:
                currentMapStyle = .hybrid()
            case .hybrid:
                currentMapStyle = .imagery()
            case .imagery:
                currentMapStyle = .standard(elevation: .realistic)
            default:
                currentMapStyle = .standard(elevation: .realistic)
            }
        }
    }
    
    func toggleFullScreen() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isFullScreen.toggle()
            mapInteractionModes = isFullScreen ? .all : .basic
        }
    }
    
    func handleMapTap(at location: CGPoint, in geometry: GeometryProxy) {
        // Convert tap location to coordinate and find nearest interactive point
        // Show detailed stats for that point
    }
    
    func selectPoint(_ point: InteractiveRoutePointData) {
        selectedPointId = point.id
        showDetailedPoints = true
        
        // Show point details in a popup or bottom sheet
    }
    
    func showPhoto(_ photo: PhotoAnnotationData) {
        // Show photo in full screen or detail view
    }
    
    // MARK: - Export and Sharing
    
    func exportSession() {
        // Export session as GPX file
        Task {
            // Implementation for GPX export
        }
    }
    
    func shareSession() {
        // Share session summary and route
        Task {
            // Implementation for social sharing
        }
    }
    
    func printSummary() {
        // Print session summary
        Task {
            // Implementation for printing
        }
    }
    
    func saveRoute() {
        // Save route as template for future use
        Task {
            // Implementation for saving route template
        }
    }
    
    // MARK: - Chart Helpers
    
    func formatChartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func colorForTerrain(_ terrain: TerrainType) -> Color {
        switch terrain {
        case .pavedRoad: return .blue
        case .trail: return .green
        case .gravel: return .orange
        case .sand: return .yellow
        case .mud: return .brown
        case .snow: return .cyan
        case .stairs: return .purple
        case .grass: return .mint
        }
    }
    
    private func calculateInstantaneousPace(at index: Int) -> Double {
        guard let session = session, index > 0, index < session.locationPoints.count else { return 0 }
        
        let current = session.locationPoints[index]
        let previous = session.locationPoints[index - 1]
        
        let distance = current.distance(to: previous)
        let time = current.timestamp.timeIntervalSince(previous.timestamp)
        
        guard time > 0, distance > 0 else { return 0 }
        
        // Return pace in minutes per kilometer
        return (time / 60.0) / (distance / 1000.0)
    }
    
    private func calculateInstantaneousPace(for point: LocationPoint) -> Double {
        guard let session = session,
              let index = session.locationPoints.firstIndex(of: point) else { return 0 }
        
        return calculateInstantaneousPace(at: index)
    }
    
    private func calculateDistanceAtPoint(_ index: Int) -> Double {
        guard let session = session, index < session.locationPoints.count else { return 0 }
        
        var totalDistance: Double = 0
        
        for i in 1...index {
            let current = session.locationPoints[i]
            let previous = session.locationPoints[i - 1]
            totalDistance += current.distance(to: previous)
        }
        
        return totalDistance
    }
}

// MARK: - Supporting Data Types

struct TerrainSegmentPolyline: Identifiable {
    let id: UUID
    let polyline: MKPolyline
    let terrainType: TerrainType
    let terrainColor: Color
}

struct DistanceMarkerData: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let distance: Double
    let title: String
    let splitTime: String
}

struct PhotoAnnotationData: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let imageURL: URL
    let timestamp: Date
    let caption: String?
}

struct InteractiveRoutePointData: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let elevation: Double
    let pace: Double
    let timeText: String
    let elevationText: String
}

struct ReplayStats {
    let timeText: String
    let distanceText: String
    let paceText: String
    let elevationText: String
}

struct TimelineSegment: Identifiable {
    let id: UUID
    let relativeWidth: Double
    let color: Color
}

struct PaceDataPoint: Identifiable {
    let id: UUID
    let time: Date
    let pace: Double
}

struct ElevationDataPoint: Identifiable {
    let id: UUID
    let time: Date
    let elevation: Double
}

struct HeartRateDataPoint: Identifiable {
    let id: UUID
    let time: Date
    let heartRate: Double
}

struct TerrainChartSegment: Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let color: Color
}

struct TerrainBreakdownData: Identifiable {
    let id = UUID()
    let terrain: TerrainType
    let percentage: Double
    let color: Color
}

struct SplitTimeData: Identifiable {
    let id = UUID()
    let distance: Double
    let timeText: String
    let paceText: String
}

// MARK: - Supporting Views

/// Custom stat card with iOS 26 Liquid Glass preparation
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// Distance marker annotation for route
struct DistanceMarker: View {
    let distance: Double
    let units: String
    let splitTime: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.orange)
                    .frame(width: 28, height: 28)
                
                Text("\(Int(distance))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 2) {
                Text(units == "km" ? "km" : "mi")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(splitTime)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityLabel("Distance marker: \(Int(distance)) \(units == "km" ? "kilometers" : "miles")")
        .accessibilityValue("Split time: \(splitTime)")
    }
}

/// Replay position marker with animation
struct ReplayPositionMarker: View {
    let isAnimating: Bool
    let heading: Double
    
    var body: some View {
        ZStack {
            // Pulsing circle for visibility
            Circle()
                .stroke(.blue, lineWidth: 3)
                .frame(width: 40, height: 40)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            
            // Direction arrow
            Image(systemName: "location.north.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(heading))
        }
        .accessibilityLabel("Current replay position")
        .accessibilityHint("Shows current position during route replay")
    }
}

/// Interactive route point for detailed stats
struct InteractiveRoutePoint: View {
    let point: InteractiveRoutePointData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(isSelected ? .armyGreenPrimary : .clear)
                .stroke(.armyGreenPrimary, lineWidth: 2)
                .frame(width: 12, height: 12)
                .scaleEffect(isSelected ? 1.5 : 1.0)
        }
        .accessibilityLabel("Route point at \(point.timeText)")
        .accessibilityValue("Elevation: \(point.elevationText), Pace: \(formatPace(point.pace))")
        .accessibilityHint("Double tap for detailed statistics")
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Photo annotation marker
struct PhotoAnnotation: View {
    let photo: PhotoAnnotationData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                    .shadow(radius: 2)
                
                Image(systemName: "camera.fill")
                    .font(.caption)
                    .foregroundColor(.armyGreenPrimary)
            }
        }
        .accessibilityLabel("Photo taken during session")
        .accessibilityHint("Double tap to view photo")
    }
}

/// Bottom sheet container with drag gesture
struct BottomSheet<Content: View>: View {
    @Binding var isExpanded: Bool
    let maxHeight: CGFloat
    let content: Content
    
    @GestureState private var dragOffset: CGSize = .zero
    
    init(isExpanded: Binding<Bool>, maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self._isExpanded = isExpanded
        self.maxHeight = maxHeight
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .offset(y: dragOffset.height)
        .animation(.interactiveSpring(), value: isExpanded)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    if value.translation.y > threshold {
                        isExpanded = false
                    } else if value.translation.y < -threshold {
                        isExpanded = true
                    }
                }
        )
    }
}

// MARK: - Route Marker (Reused from MapView)

struct RouteMarker: View {
    enum MarkerType: CaseIterable {
        case start
        case end
        
        var color: Color {
            switch self {
            case .start: return .green
            case .end: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .start: return "flag.fill"
            case .end: return "checkered.flag"
            }
        }
    }
    
    let type: MarkerType
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(type.color)
                    .frame(width: 32, height: 32)
                
                Image(systemName: type.icon)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityLabel("\(title) marker")
        .accessibilityValue(subtitle)
    }
}

// MARK: - Preview

#Preview {
    let session = RuckSession()
    
    DetailedSessionView(session: session)
        .environmentObject(DataCoordinator())
}