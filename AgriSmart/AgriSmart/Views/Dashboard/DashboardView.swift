import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var alertVM: AlertViewModel
    @StateObject private var cropVM = CropLogViewModel()
    @State private var showAIDoctor = false
    @State private var showCropEntry = false
    @State private var showFinancial = false
    @State private var showServiceMap = false
    @State private var showCalculator = false
    @State private var showInsights = false
    @State private var showReports = false

    var user: AppUser? { authVM.currentUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Green header
                    dashHeader
                    // Quick actions
                    quickActions
                    // Alerts
                    if !alertVM.alerts.filter({ !$0.isRead }).isEmpty { urgentAlerts }
                    // Active Crops
                    activeCrops
                    // Quick Stats
                    quickStats
                }
            }
            .background(Color.agriBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAIDoctor) { AIPlantDoctorView() }
            .sheet(isPresented: $showCropEntry) {
                NavigationStack { CropEntryFormView(cropLog: nil) }
            }
            .sheet(isPresented: $showFinancial) { FinancialVaultView() }
            .sheet(isPresented: $showServiceMap) { ServiceLocatorView() }
            .sheet(isPresented: $showCalculator) { NavigationStack { CalculatorView() } }
            .sheet(isPresented: $showInsights) { NavigationStack { InsightsView() } }
            .sheet(isPresented: $showReports) { NavigationStack { ReportListView() } }
        }
        .onAppear {
            guard let uid = user?.uid else { return }
            cropVM.startListening(userId: uid)
            alertVM.startListening(userId: uid)
        }
    }

    // MARK: - Header
    var dashHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: "#1a5c2e"), Color(hex: "#2d8a4e")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 180)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Good \(greeting) 🌤")
                            .font(.subheadline).foregroundColor(.white.opacity(0.8))
                        Text(user?.farmName ?? "My Farm")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    }
                    Spacer()
                    NavigationLink(destination: ProfileView()) {
                        ZStack {
                            Circle().fill(.white.opacity(0.2)).frame(width: 44, height: 44)
                            Text(user?.fullName.prefix(2).uppercased() ?? "U")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                HStack(spacing: 6) {
                    Image(systemName: "location.fill").font(.caption).foregroundColor(.white.opacity(0.8))
                    Text(user?.district ?? "Sri Lanka").font(.caption).foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Image(systemName: "bell.badge.fill").font(.caption)
                        .foregroundColor(alertVM.unreadCount > 0 ? Color(hex: "#FFD60A") : .white.opacity(0.5))
                    if alertVM.unreadCount > 0 {
                        Text("\(alertVM.unreadCount) alerts")
                            .font(.caption.bold()).foregroundColor(Color(hex: "#FFD60A"))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 20)
            }
        }
    }

    // MARK: - Quick Actions
    var quickActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            QuickActionButton(icon: "stethoscope", label: "AI Doctor", color: Color(hex: "#30D158")) { showAIDoctor = true }
            QuickActionButton(icon: "leaf.fill", label: "Crop Log", color: .agriGreen) { showCropEntry = true }
            QuickActionButton(icon: "map.fill", label: "Services", color: Color(hex: "#007AFF")) { showServiceMap = true }
            QuickActionButton(icon: "lock.shield.fill", label: "Finance", color: Color(hex: "#FF9F0A")) { showFinancial = true }
            QuickActionButton(icon: "scalemass.fill", label: "Calculator", color: Color(hex: "#5856D6")) { showCalculator = true }
            QuickActionButton(icon: "chart.bar.fill", label: "Insights", color: Color(hex: "#FF6B35")) { showInsights = true }
            QuickActionButton(icon: "doc.text.fill", label: "Reports", color: Color(hex: "#32ADE6")) { showReports = true }
            QuickActionButton(icon: "gearshape.fill", label: "Settings", color: Color(hex: "#8E8E93")) { }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.agriBackground)
    }

    // MARK: - Urgent Alerts
    var urgentAlerts: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "⚠ Active Alerts", action: "See All")
            ForEach(alertVM.alerts.filter { !$0.isRead }.prefix(2)) { alert in
                AlertRowCard(alert: alert) {
                    Task { await alertVM.markRead(alert) }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Active Crops
    var activeCrops: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "🌾 Active Crops", action: "View All")
            let growing = cropVM.cropLogs.filter { $0.status == .growing }.prefix(3)
            if growing.isEmpty {
                EmptyStateCard(icon: "leaf", message: "No active crops yet.\nTap + to add your first crop log.")
            } else {
                ForEach(Array(growing)) { log in
                    CropRowCard(cropLog: log)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Quick Stats
    var quickStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Farm Overview")
            HStack(spacing: 10) {
                StatCard(value: "\(cropVM.cropLogs.filter { $0.status == .growing }.count)",
                         label: "Growing", icon: "leaf.fill", color: .agriGreen)
                StatCard(value: "\(cropVM.cropLogs.filter { $0.status == .readyToHarvest }.count)",
                         label: "Ready", icon: "clock.badge.checkmark", color: .orange)
                StatCard(value: "\(cropVM.cropLogs.filter { $0.status == .harvested }.count)",
                         label: "Harvested", icon: "checkmark.circle", color: .blue)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 24)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Morning" } else if hour < 17 { return "Afternoon" } else { return "Evening" }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
                    .frame(width: 50, height: 50).background(color.opacity(0.12)).cornerRadius(14)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Alert Row Card
struct AlertRowCard: View {
    let alert: AgriAlert
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            AlertIconView(type: alert.type)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title).font(.subheadline).fontWeight(.semibold)
                Text(alert.message).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.agriCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(alertBorderColor(alert.type).opacity(0.3), lineWidth: 1))
    }

    func alertBorderColor(_ type: AlertType) -> Color {
        switch type {
        case .watering: return .blue
        case .fertilizing: return .green
        case .disease: return .red
        case .harvest: return .orange
        case .general: return .secondary
        }
    }
}

// MARK: - Crop Row Card
struct CropRowCard: View {
    let cropLog: CropLog
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.agriGreen.opacity(0.1)).frame(width: 46, height: 46)
                Text(cropIcon(cropLog.cropName)).font(.title2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(cropLog.cropName).font(.subheadline).fontWeight(.semibold)
                Text("\(cropLog.fieldName) · Day \(cropLog.daysPlanted)").font(.caption).foregroundColor(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(Color.agriGreen)
                            .frame(width: geo.size.width * cropLog.progressPercent, height: 5)
                            .animation(.easeInOut, value: cropLog.progressPercent)
                    }
                }
                .frame(height: 5)
            }
            Spacer()
            ProgressRing(progress: cropLog.progressPercent, size: 40)
        }
        .padding(12).background(Color.agriCard).cornerRadius(14)
    }

    func cropIcon(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("paddy") || lower.contains("rice") { return "🌾" }
        if lower.contains("chilli") { return "🌶" }
        if lower.contains("onion") { return "🧅" }
        if lower.contains("tomato") { return "🍅" }
        if lower.contains("maize") || lower.contains("corn") { return "🌽" }
        if lower.contains("potato") { return "🥔" }
        return "🌿"
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    let icon: String; let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundColor(.agriGreen.opacity(0.5))
            Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(28)
        .background(Color.agriCard).cornerRadius(14)
    }
}
