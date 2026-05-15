import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel

    // Notification toggles
    @AppStorage("notif_watering")   private var wateringAlerts = true
    @AppStorage("notif_fertilizing") private var fertilizingAlerts = true
    @AppStorage("notif_harvest")    private var harvestAlerts = true
    @AppStorage("notif_disease")    private var diseaseAlerts = true
    @AppStorage("notif_sound")      private var notifSound = true

    // Security
    @AppStorage("biometric_vault")  private var biometricVault = true
    @AppStorage("biometric_login")  private var biometricLogin = false

    // Accessibility
    @AppStorage("large_text")       private var largeText = false
    @AppStorage("high_contrast")    private var highContrast = false
    @AppStorage("reduce_motion")    private var reduceMotion = false

    // App preferences
    @AppStorage("app_language")     private var appLanguage = "English"

    @State private var showNotifPermissionAlert = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var showDataDeleteConfirm = false

    var body: some View {
        Form {

            // MARK: Notifications
            Section {
                ToggleRow(icon: "drop.fill", iconColor: .blue,
                          label: "Watering Reminders",
                          subtitle: "Daily at 6:00 AM based on crop stage",
                          isOn: $wateringAlerts)
                    .onChange(of: wateringAlerts) { _ in updateNotifications() }

                ToggleRow(icon: "leaf.fill", iconColor: .green,
                          label: "Fertilizing Alerts",
                          subtitle: "Based on crop growth cycle",
                          isOn: $fertilizingAlerts)
                    .onChange(of: fertilizingAlerts) { _ in updateNotifications() }

                ToggleRow(icon: "chart.bar.fill", iconColor: .orange,
                          label: "Harvest Reminders",
                          subtitle: "7 days before expected harvest",
                          isOn: $harvestAlerts)
                    .onChange(of: harvestAlerts) { _ in updateNotifications() }

                ToggleRow(icon: "cross.circle.fill", iconColor: .red,
                          label: "Disease Alerts",
                          subtitle: "High humidity & risk warnings",
                          isOn: $diseaseAlerts)
                    .onChange(of: diseaseAlerts) { _ in updateNotifications() }

                ToggleRow(icon: "speaker.wave.2.fill", iconColor: Color(hex: "#8E8E93"),
                          label: "Notification Sounds",
                          subtitle: "Play sound with alerts",
                          isOn: $notifSound)

                if notifStatus == .denied {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Disabled").font(.caption).fontWeight(.semibold)
                            Text("Enable in iOS Settings → AgriSmart → Notifications")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                        }
                        .font(.caption).foregroundColor(.agriGreen)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Label("Notifications", systemImage: "bell.fill")
            }

            // MARK: Security
            Section {
                ToggleRow(icon: "faceid", iconColor: .agriGreen,
                          label: "Face ID / Biometrics",
                          subtitle: "Protect Financial Vault access",
                          isOn: $biometricVault)

                ToggleRow(icon: "lock.fill", iconColor: .secondary,
                          label: "Biometric Login",
                          subtitle: "Sign in using \(BiometricAuthService.shared.biometricTypeName)",
                          isOn: $biometricLogin)

                NavigationLink(destination: ChangePasswordView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change Password").font(.body)
                            Text("Update your account password").font(.caption).foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "key.fill")
                            .foregroundColor(.white).frame(width: 30, height: 30)
                            .background(Color.orange).cornerRadius(7)
                    }
                }
            } header: {
                Label("Security", systemImage: "lock.shield.fill")
            }

            // MARK: Accessibility
            Section {
                ToggleRow(icon: "textformat.size.larger", iconColor: .blue,
                          label: "Large Text",
                          subtitle: "Increase text size throughout the app",
                          isOn: $largeText)

                ToggleRow(icon: "circle.lefthalf.filled", iconColor: .secondary,
                          label: "High Contrast",
                          subtitle: "Increase contrast for better readability",
                          isOn: $highContrast)

                ToggleRow(icon: "hand.raised.fill", iconColor: .purple,
                          label: "Reduce Motion",
                          subtitle: "Minimize animations",
                          isOn: $reduceMotion)

                HStack {
                    Label {
                        Text("Language")
                    } icon: {
                        Image(systemName: "globe")
                            .foregroundColor(.white).frame(width: 30, height: 30)
                            .background(Color(hex: "#32ADE6")).cornerRadius(7)
                    }
                    Spacer()
                    Picker("Language", selection: $appLanguage) {
                        Text("English").tag("English")
                        Text("සිංහල").tag("Sinhala")
                        Text("தமிழ்").tag("Tamil")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            } header: {
                Label("Accessibility", systemImage: "accessibility")
            }

            // MARK: App Information
            Section {
                HStack {
                    Label("Version", systemImage: "info.circle.fill")
                    Spacer()
                    Text("1.0.0 (Build 1)").foregroundColor(.secondary).font(.subheadline)
                }

                Link(destination: URL(string: "https://agrismart.lk/privacy")!) {
                    Label("Privacy Policy", systemImage: "lock.doc.fill")
                }

                Link(destination: URL(string: "https://agrismart.lk/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                }

                Link(destination: URL(string: "mailto:support@agrismart.lk")!) {
                    Label("Contact Support", systemImage: "envelope.fill")
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }

            // MARK: Danger Zone
            Section {
                Button(role: .destructive) {
                    showDataDeleteConfirm = true
                } label: {
                    Label("Delete All My Data", systemImage: "trash.fill")
                        .foregroundColor(.red)
                }
            } header: {
                Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
            } footer: {
                Text("Deleting your data is permanent and cannot be undone.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { checkNotificationStatus() }
        .confirmationDialog("Delete All Data?", isPresented: $showDataDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { /* delete all user data */ }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your crop logs, financial records, and alerts. Your account will also be removed.")
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { notifStatus = settings.authorizationStatus }
        }
    }

    private func updateNotifications() {
        // If notifications disabled, request permission
        if notifStatus == .notDetermined {
            Task { await NotificationManager.shared.requestPermission() }
        }
    }
}

// MARK: - Toggle Row
struct ToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.body)
                    if let sub = subtitle {
                        Text(sub).font(.caption).foregroundColor(.secondary)
                    }
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(iconColor)
                    .cornerRadius(7)
            }
        }
        .tint(.agriGreen)
    }
}

// MARK: - Change Password View
struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section("Current") {
                SecureField("Current Password", text: $currentPassword)
            }
            Section("New Password") {
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
            }
            if let msg = message {
                Section {
                    HStack {
                        Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(isError ? .red : .green)
                        Text(msg).font(.caption).foregroundColor(isError ? .red : .green)
                    }
                }
            }
            Section {
                AgriButton(title: "Update Password", isLoading: isSaving) {
                    updatePassword()
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func updatePassword() {
        guard newPassword == confirmPassword, !newPassword.isEmpty else {
            message = "Passwords do not match"; isError = true; return
        }
        guard newPassword.count >= 8 else {
            message = "Password must be at least 8 characters"; isError = true; return
        }
        isSaving = true
        // Re-authenticate and update password via Firebase Auth
        Task {
            do {
                guard let user = Auth.auth().currentUser,
                      let email = user.email else { return }
                let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
                try await user.reauthenticate(with: credential)
                try await user.updatePassword(to: newPassword)
                await MainActor.run {
                    message = "Password updated successfully"
                    isError = false
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    isError = true
                    isSaving = false
                }
            }
        }
    }
}

// Missing import for Auth in Settings
import FirebaseAuth
