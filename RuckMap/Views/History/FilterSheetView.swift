import SwiftUI

/// Comprehensive filter sheet for session history
/// Provides granular filtering options with intuitive controls
struct FilterSheetView: View {
    @Bindable var viewModel: SessionHistoryViewModel
    let preferredUnits: String
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                timeRangeSection
                distanceSection
                loadWeightSection
                terrainSection
                weatherSection
                performanceSection
                favoritesSection
            }
            .navigationTitle("Filter Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearAllFilters()
                    }
                    .disabled(!viewModel.hasActiveFilters)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Filter Sections
    
    private var timeRangeSection: some View {
        Section {
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    HStack {
                        Image(systemName: range.systemImage)
                        Text(range.rawValue)
                    }
                    .tag(range)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Label("Time Range", systemImage: "calendar")
        }
    }
    
    private var distanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Distance Range")
                        .font(.subheadline)
                    Spacer()
                    Text(formatDistanceRange())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                RangeSlider(
                    range: $viewModel.distanceRange,
                    bounds: 0...50,
                    step: 1,
                    units: preferredUnits == "imperial" ? "mi" : "km"
                )
            }
        } header: {
            Label("Distance", systemImage: "map")
        }
    }
    
    private var loadWeightSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Load Weight Range")
                        .font(.subheadline)
                    Spacer()
                    Text(formatWeightRange())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                RangeSlider(
                    range: $viewModel.loadWeightRange,
                    bounds: 0...100,
                    step: 5,
                    units: preferredUnits == "imperial" ? "lbs" : "kg"
                )
            }
        } header: {
            Label("Load Weight", systemImage: "backpack")
        }
    }
    
    private var terrainSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(TerrainType.allCases, id: \.self) { terrain in
                    TerrainFilterChip(
                        terrain: terrain,
                        isSelected: viewModel.selectedTerrainTypes.contains(terrain)
                    ) {
                        toggleTerrain(terrain)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack {
                Label("Terrain Types", systemImage: "mountain.2")
                Spacer()
                Button("All") {
                    viewModel.selectedTerrainTypes = Set(TerrainType.allCases)
                }
                .font(.caption)
                .disabled(viewModel.selectedTerrainTypes == Set(TerrainType.allCases))
                
                Button("None") {
                    viewModel.selectedTerrainTypes.removeAll()
                }
                .font(.caption)
                .disabled(viewModel.selectedTerrainTypes.isEmpty)
            }
        }
    }
    
    private var weatherSection: some View {
        Section {
            VStack(spacing: 16) {
                // Temperature range
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Temperature")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(viewModel.temperatureRange.lowerBound))°C to \(Int(viewModel.temperatureRange.upperBound))°C")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    RangeSlider(
                        range: $viewModel.temperatureRange,
                        bounds: -20...50,
                        step: 5,
                        units: "°C"
                    )
                }
                
                // Wind speed
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Wind Speed")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(viewModel.windSpeedMax)) m/s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $viewModel.windSpeedMax,
                        in: 0...50,
                        step: 5
                    )
                }
                
                // Precipitation
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Max Precipitation")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(viewModel.precipitationMax)) mm/hr")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $viewModel.precipitationMax,
                        in: 0...50,
                        step: 5
                    )
                }
            }
        } header: {
            Label("Weather Conditions", systemImage: "cloud.sun")
        }
    }
    
    private var performanceSection: some View {
        Section {
            VStack(spacing: 16) {
                // Minimum calories
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Minimum Calories")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(viewModel.minCalories))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $viewModel.minCalories,
                        in: 0...2000,
                        step: 50
                    )
                }
                
                // Minimum elevation gain
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Minimum Elevation Gain")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(viewModel.minElevationGain))m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: $viewModel.minElevationGain,
                        in: 0...2000,
                        step: 50
                    )
                }
            }
        } header: {
            Label("Performance", systemImage: "chart.line.uptrend.xyaxis")
        }
    }
    
    private var favoritesSection: some View {
        Section {
            Toggle(isOn: $viewModel.showOnlyFavorites) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("Show Only Favorites")
                }
            }
        } header: {
            Label("Favorites", systemImage: "heart")
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleTerrain(_ terrain: TerrainType) {
        if viewModel.selectedTerrainTypes.contains(terrain) {
            viewModel.selectedTerrainTypes.remove(terrain)
        } else {
            viewModel.selectedTerrainTypes.insert(terrain)
        }
    }
    
    private func formatDistanceRange() -> String {
        if preferredUnits == "imperial" {
            let lowerMiles = viewModel.distanceRange.lowerBound * 0.621371
            let upperMiles = viewModel.distanceRange.upperBound * 0.621371
            return String(format: "%.1f - %.1f mi", lowerMiles, upperMiles)
        } else {
            return String(format: "%.1f - %.1f km", viewModel.distanceRange.lowerBound, viewModel.distanceRange.upperBound)
        }
    }
    
    private func formatWeightRange() -> String {
        if preferredUnits == "imperial" {
            let lowerLbs = viewModel.loadWeightRange.lowerBound * 2.20462
            let upperLbs = viewModel.loadWeightRange.upperBound * 2.20462
            return String(format: "%.0f - %.0f lbs", lowerLbs, upperLbs)
        } else {
            return String(format: "%.0f - %.0f kg", viewModel.loadWeightRange.lowerBound, viewModel.loadWeightRange.upperBound)
        }
    }
}

// MARK: - Supporting Views

/// Terrain filter chip with selection state
struct TerrainFilterChip: View {
    let terrain: TerrainType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: terrain.icon)
                    .font(.caption)
                Text(terrain.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.ruckMapPrimary : Color.ruckMapTertiaryBackground)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.ruckMapPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Custom range slider for filtering
struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    let step: Double
    let units: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom range slider implementation
            // For now, using two separate sliders
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { range.lowerBound },
                            set: { newValue in
                                let clampedValue = min(newValue, range.upperBound - step)
                                range = clampedValue...range.upperBound
                            }
                        ),
                        in: bounds,
                        step: step
                    )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { range.upperBound },
                            set: { newValue in
                                let clampedValue = max(newValue, range.lowerBound + step)
                                range = range.lowerBound...clampedValue
                            }
                        ),
                        in: bounds,
                        step: step
                    )
                }
            }
        }
    }
}

#Preview {
    FilterSheetView(
        viewModel: SessionHistoryViewModel(),
        preferredUnits: "imperial"
    )
}