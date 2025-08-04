import SwiftUI

struct SettingsView: View {
    @Environment(WatchAppCoordinator.self) var appCoordinator
    @State private var showingPermissionsSheet = false
    @State private var showingStorageInfo = false
    @State private var showingAbout = false
    
    private var healthKitManager: WatchHealthKitManager? {
        appCoordinator.healthKitManager
    }
    
    private var dataManager: WatchDataManager? {
        appCoordinator.dataManager
    }
    
    var body: some View {
        NavigationView {
            List {
                // Permissions Section
                Section("Permissions") {
                    Button(action: { showingPermissionsSheet = true }) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Permissions")
                                    .font(.caption)
                                
                                Text(permissionsStatus)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if !appCoordinator.permissionsGranted {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                
                // Storage Section
                Section("Storage") {
                    Button(action: { showingStorageInfo = true }) {
                        HStack {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Storage Info")
                                    .font(.caption)
                                
                                Text(storageStatus)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Health Integration
                Section("Health") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HealthKit")
                                .font(.caption)
                            
                            Text(healthKitStatus)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if healthKitManager?.isAuthorized == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                        }
                    }
                }
                
                // About Section
                Section("About") {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            
                            Text("About RuckMap")
                                .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.carousel)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingPermissionsSheet) {
            PermissionsView()
        }
        .sheet(isPresented: $showingStorageInfo) {
            StorageInfoView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var permissionsStatus: String {
        if appCoordinator.permissionsGranted {
            return "All permissions granted"
        } else {
            return "Some permissions needed"
        }
    }
    
    private var storageStatus: String {
        if let stats = dataManager?.getStorageStats() {
            return "\(stats.sessionCount) sessions, \(String(format: "%.1f", stats.estimatedSizeMB)) MB"
        }
        return "Storage info unavailable"
    }
    
    private var healthKitStatus: String {
        if healthKitManager?.isAuthorized == true {
            return "Connected"
        } else {
            return "Not connected"
        }
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    @Environment(WatchAppCoordinator.self) var appCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Permissions")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    PermissionRow(
                        title: "Location",
                        description: "Required for GPS tracking",
                        icon: "location.fill",
                        isGranted: true // Location permission handled by system
                    )
                    
                    PermissionRow(
                        title: "HealthKit",
                        description: "For heart rate and body metrics",
                        icon: "heart.fill",
                        isGranted: appCoordinator.healthKitManager?.isAuthorized == true
                    )
                }
                
                Button("Grant Permissions") {
                    Task {
                        do {
                            try await appCoordinator.healthKitManager?.requestAuthorization()
                            appCoordinator.locationManager?.requestLocationPermission()
                        } catch {
                            print("Permission request failed: \(error)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appCoordinator.permissionsGranted)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let title: String
    let description: String
    let icon: String
    let isGranted: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isGranted ? .green : .red)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Storage Info View

struct StorageInfoView: View {
    @Environment(WatchAppCoordinator.self) var appCoordinator
    @Environment(\.dismiss) private var dismiss
    
    private var storageStats: WatchStorageStats? {
        appCoordinator.dataManager?.getStorageStats()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Storage Information")
                    .font(.headline)
                
                if let stats = storageStats {
                    VStack(spacing: 12) {
                        StorageStatRow(
                            title: "Sessions",
                            value: "\(stats.sessionCount)",
                            icon: "folder.fill"
                        )
                        
                        StorageStatRow(
                            title: "Location Points",
                            value: "\(stats.locationPointCount)",
                            icon: "location.fill"
                        )
                        
                        StorageStatRow(
                            title: "Storage Used",
                            value: String(format: "%.1f MB", stats.estimatedSizeMB),
                            icon: "internaldrive"
                        )
                    }
                    
                    Divider()
                    
                    VStack(spacing: 8) {
                        Text("Data Retention")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("Sessions are automatically deleted after 48 hours to preserve Watch storage.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Storage information unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Storage Stat Row

struct StorageStatRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("RuckMap Watch")
                    .font(.headline)
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(spacing: 8) {
                    Text("Standalone ruck tracking for Apple Watch")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    
                    Text("Track your ruck marches with GPS, heart rate monitoring, and calorie tracking - all without your iPhone.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    Text("Features")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        FeatureRow(text: "Standalone GPS tracking")
                        FeatureRow(text: "Heart rate monitoring")
                        FeatureRow(text: "Calorie calculation")
                        FeatureRow(text: "Auto-pause detection")
                        FeatureRow(text: "48-hour local storage")
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption2)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WatchAppCoordinator())
}