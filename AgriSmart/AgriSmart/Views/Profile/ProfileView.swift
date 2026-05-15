import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showEditProfile = false
    @State private var showLogoutConfirm = false
    @State private var cropCount = 0
    @State private var harvestCount = 0

    var user: AppUser? { authVM.currentUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Profile Header
                    ZStack(alignment: .bottom) {
                        LinearGradient(colors: [Color(hex: "#1a5c2e"), Color(hex: "#2d8a4e")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 200)

                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.25))
                                    .frame(width: 80, height: 80)
                                Text(initials)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .overlay(
                                Circle().stroke(.white.opacity(0.5), lineWidth: 2)
                            )

                            VStack(spacing: 4) {
                                Text(user?.fullName ?? "Farmer").font(.title3).fontWeight(.bold).foregroundColor(.white)
                                Text(user?.primaryCropType ?? "Sri Lankan Farmer")
                                    .font(.subheadline).foregroundColor(.white.opacity(0.75))
                                Text("📍 \(user?.district ?? "")")
                                    .font(.caption).foregroundColor(.white.opacity(0.6))
                            }

                            Button { showEditProfile = true } label: {
                                Text("Edit Profile")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20).padding(.vertical, 6)
                                    .background(.white.opacity(0.2))
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    // Stats Row
                    HStack(spacing: 0) {
                        ProfileStatItem(value: String(format: "%.1f", user?.farmSizeAcres ?? 0), label: "Acres")
                        Divider().frame(height: 40)
                        ProfileStatItem(value: "\(cropCount)", label: "Crops")
                        Divider().frame(height: 40)
                        ProfileStatItem(value: "\(harvestCount)", label: "Harvests")
                        Divider().frame(height: 40)
                        ProfileStatItem(value: user?.district.prefix(4).description ?? "—", label: "District")
                    }
                    .background(Color.agriCard)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                    .padding(.bottom, 20)

                    // Farm Information
                    SectionHeader(title: "Farm Information")
                    VStack(spacing: 0) {
                        ProfileInfoRow(icon: "house.fill", iconColor: .agriGreen, label: "Farm Name",
                                       value: user?.farmName ?? "—")
                        Divider().padding(.leading, 52)
                        ProfileInfoRow(icon: "ruler.fill", iconColor: .blue, label: "Farm Size",
                                       value: "\(user?.farmSizeAcres ?? 0) Acres")
                        Divider().padding(.leading, 52)
                        ProfileInfoRow(icon: "leaf.fill", iconColor: .green, label: "Primary Crop",
                                       value: user?.primaryCropType ?? "—")
                        Divider().padding(.leading, 52)
                        ProfileInfoRow(icon: "location.fill", iconColor: .orange, label: "District",
                                       value: user?.district ?? "—")
                    }
                    .background(Color.agriCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // Contact Information
                    SectionHeader(title: "Contact Information")
                    VStack(spacing: 0) {
                        ProfileInfoRow(icon: "phone.fill", iconColor: .green, label: "Mobile",
                                       value: user?.mobile ?? "—")
                        if let email = user?.email, !email.isEmpty {
                            Divider().padding(.leading, 52)
                            ProfileInfoRow(icon: "envelope.fill", iconColor: .blue, label: "Email",
                                           value: email)
                        }
                    }
                    .background(Color.agriCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // App Actions
                    SectionHeader(title: "Account")
                    VStack(spacing: 0) {
                        NavigationLink(destination: SettingsView()) {
                            AgriListRow(icon: "gearshape.fill", iconColor: Color(hex: "#8E8E93"),
                                        label: "Settings") { EmptyView() }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        Divider().padding(.leading, 52)

                        Button {
                            guard let url = URL(string: "https://agrismart.lk/help") else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            AgriListRow(icon: "questionmark.circle.fill", iconColor: .blue,
                                        label: "Help & Support") { EmptyView() }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .foregroundColor(.primary)
                        Divider().padding(.leading, 52)

                        Button {
                            guard let url = URL(string: "https://agrismart.lk/privacy") else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            AgriListRow(icon: "lock.doc.fill", iconColor: .secondary,
                                        label: "Privacy Policy") { EmptyView() }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .foregroundColor(.primary)
                        Divider().padding(.leading, 52)

                        Button { showLogoutConfirm = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.red)
                                    .cornerRadius(7)
                                Text("Sign Out").font(.body).foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                    }
                    .background(Color.agriCard)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // Version
                    Text("AgriSmart v1.0.0 · Built for Sri Lankan Farmers")
                        .font(.caption2).foregroundColor(.secondary)
                        .padding(.vertical, 24)
                }
            }
            .background(Color.agriBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authVM.logout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of AgriSmart?")
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack { EditProfileView() }
            }
        }
        .onAppear { loadCounts() }
    }

    private var initials: String {
        let parts = (user?.fullName ?? "U").split(separator: " ")
        let first = parts.first?.prefix(1) ?? "U"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }

    private func loadCounts() {
        guard let uid = user?.uid else { return }
        Task {
            let logs = (try? await FirestoreService.shared.fetchCropLogs(userId: uid)) ?? []
            await MainActor.run {
                cropCount = logs.filter { $0.status == .growing }.count
                harvestCount = logs.filter { $0.status == .harvested }.count
            }
        }
    }
}

// MARK: - Profile Stat Item
struct ProfileStatItem: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Profile Info Row
struct ProfileInfoRow: View {
    let icon: String; let iconColor: Color; let label: String; let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(iconColor)
                .cornerRadius(7)
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).foregroundColor(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var fullName = ""
    @State private var farmName = ""
    @State private var farmSize = ""
    @State private var district = ""
    @State private var primaryCrop = ""
    @State private var isSaving = false

    let districts = ["Colombo","Gampaha","Kalutara","Kandy","Matale","Nuwara Eliya",
                     "Galle","Matara","Hambantota","Jaffna","Kilinochchi","Mannar",
                     "Vavuniya","Trincomalee","Batticaloa","Ampara",
                     "Kurunegala","Puttalam","Anuradhapura","Polonnaruwa","Badulla",
                     "Monaragala","Ratnapura","Kegalle"]

    var body: some View {
        Form {
            Section("Personal") {
                TextField("Full Name", text: $fullName)
            }
            Section("Farm Details") {
                TextField("Farm Name", text: $farmName)
                HStack {
                    TextField("Farm Size", text: $farmSize).keyboardType(.decimalPad)
                    Text("Acres").foregroundColor(.secondary)
                }
                Picker("District", selection: $district) {
                    ForEach(districts, id: \.self) { Text($0).tag($0) }
                }
                Picker("Primary Crop", selection: $primaryCrop) {
                    ForEach(CropType.allCases, id: \.rawValue) {
                        Text("\($0.icon) \($0.rawValue)").tag($0.rawValue)
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") {
                    isSaving = true
                    Task {
                        var data: [String: Any] = [:]
                        if !fullName.isEmpty { data["fullName"] = fullName }
                        if !farmName.isEmpty { data["farmName"] = farmName }
                        if let fs = Double(farmSize) { data["farmSizeAcres"] = fs }
                        if !district.isEmpty { data["district"] = district }
                        if !primaryCrop.isEmpty { data["primaryCropType"] = primaryCrop }
                        await authVM.updateProfile(data: data)
                        await MainActor.run { dismiss() }
                    }
                }
                .fontWeight(.semibold).disabled(isSaving)
            }
        }
        .onAppear {
            let u = authVM.currentUser
            fullName = u?.fullName ?? ""
            farmName = u?.farmName ?? ""
            farmSize = "\(u?.farmSizeAcres ?? 0)"
            district = u?.district ?? ""
            primaryCrop = u?.primaryCropType ?? ""
        }
    }
}
