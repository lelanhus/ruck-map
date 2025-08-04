import SwiftUI
import HealthKit

/// View for requesting and managing HealthKit permissions
struct HealthKitPermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var healthKitManager: HealthKitManager
    
    @State private var isRequestingPermissions = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text("HealthKit Integration")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Connect with Apple Health to enhance your rucking experience")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Benefits Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What You Get")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        PermissionBenefitRow(
                            icon: "scalemass.fill",
                            title: "Accurate Calorie Calculations",
                            description: "Uses your current weight and height for precise calorie burn estimates"
                        )
                        
                        PermissionBenefitRow(
                            icon: "heart.fill",
                            title: "Real-Time Heart Rate",
                            description: "Monitor your heart rate during rucks with Apple Watch integration"
                        )
                        
                        PermissionBenefitRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Comprehensive Fitness Tracking",
                            description: "Your ruck workouts automatically save to Apple Health and count toward Activity Rings"
                        )
                        
                        PermissionBenefitRow(
                            icon: "person.fill.badge.plus",
                            title: "Personalized Experience",
                            description: "Tailored recommendations based on your fitness data and recovery metrics"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Privacy Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Privacy")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Data stays secure")
                                        .fontWeight(.medium)
                                    Text("Your health data remains on your device and in your Apple Health app")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("You control permissions")
                                        .fontWeight(.medium)
                                    Text("Grant or revoke access anytime in Settings > Privacy & Security > Health")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Current Status
                    if healthKitManager.isHealthKitAvailable {
                        statusSection
                    } else {
                        unavailableSection
                    }
                    
                    Spacer(minLength: 32)
                }
            }
            .navigationTitle("Health Integration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if healthKitManager.isAuthorized {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.medium)
                    }
                }
            }
        }
        .alert("HealthKit Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            healthKitManager.checkAuthorizationStatus()
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 16) {
            if healthKitManager.isAuthorized {
                // Authorized state
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("HealthKit Connected")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    Text("RuckMap can now access your health data to provide enhanced tracking features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                
            } else if healthKitManager.authorizationStatus == .sharingDenied {
                // Denied state
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("Limited Access")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    Text("Some HealthKit permissions were denied. You can change this in Settings > Privacy & Security > Health")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Open Settings") {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
            } else {
                // Not determined state
                VStack(spacing: 16) {
                    Button(action: requestPermissions) {
                        HStack {
                            if isRequestingPermissions {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "heart.fill")
                            }
                            
                            Text(isRequestingPermissions ? "Requesting Permission..." : "Connect to Apple Health")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRequestingPermissions)
                    
                    Button("Continue Without HealthKit") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var unavailableSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("HealthKit Unavailable")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            Text("HealthKit is not available on this device. RuckMap will work without health integration.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Continue") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func requestPermissions() {
        isRequestingPermissions = true
        
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                
                await MainActor.run {
                    isRequestingPermissions = false
                }
                
            } catch {
                await MainActor.run {
                    isRequestingPermissions = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct PermissionBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    HealthKitPermissionsView(healthKitManager: HealthKitManager())
}