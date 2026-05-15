import SwiftUI
import FirebaseFirestore

struct AlertsCenterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var alertVM: AlertViewModel
    @State private var filterType: AlertType? = nil
    @State private var showClearConfirm = false

    var groupedAlerts: [(String, [AgriAlert])] {
        let filtered = alertVM.alerts.filter { filterType == nil || $0.type == filterType }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { alert -> String in
            if calendar.isDateInToday(alert.scheduledDate) { return "Today" }
            if calendar.isDateInYesterday(alert.scheduledDate) { return "Yesterday" }
            return DateFormatter.displayDate.string(from: alert.scheduledDate)
        }
        return grouped.sorted {
            let order = ["Today", "Yesterday"]
            let ai = order.firstIndex(of: $0.key) ?? 99
            let bi = order.firstIndex(of: $1.key) ?? 99
            return ai < bi
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isActive: filterType == nil) { filterType = nil }
                        ForEach([AlertType.watering, .fertilizing, .disease, .harvest, .general], id: \.rawValue) { type in
                            FilterChip(title: type.rawValue, isActive: filterType == type) {
                                filterType = filterType == type ? nil : type
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color.agriCard)

                if alertVM.alerts.isEmpty {
                    Spacer()
                    EmptyStateCard(icon: "bell.slash", message: "No alerts yet.\nYour crop reminders will appear here.")
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    List {
                        ForEach(groupedAlerts, id: \.0) { group, alerts in
                            Section {
                                ForEach(alerts) { alert in
                                    AlertItemRow(alert: alert)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowBackground(Color.agriBackground)
                                        .onTapGesture {
                                            if !alert.isRead { Task { await alertVM.markRead(alert) } }
                                        }
                                        .swipeActions(edge: .leading) {
                                            if !alert.isRead {
                                                Button {
                                                    Task { await alertVM.markRead(alert) }
                                                } label: {
                                                    Label("Mark Read", systemImage: "checkmark.circle")
                                                }
                                                .tint(.agriGreen)
                                            }
                                        }
                                }
                            } header: {
                                Text(group)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .kerning(0.5)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.agriBackground)
            .navigationTitle("Alerts Center")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if alertVM.unreadCount > 0 {
                        Button("Mark All Read") {
                            Task { await alertVM.markAllRead() }
                        }
                        .font(.subheadline)
                        .foregroundColor(.agriGreen)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !alertVM.alerts.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Text("Clear All").foregroundColor(.red).font(.subheadline)
                        }
                    }
                }
            }
            .confirmationDialog("Clear all alerts?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) { /* delete all alerts from Firestore */ }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all alert history.")
            }
        }
        .onAppear {
            guard let uid = authVM.currentUser?.uid else { return }
            alertVM.startListening(userId: uid)
        }
    }
}

// MARK: - Alert Item Row
struct AlertItemRow: View {
    let alert: AgriAlert

    var body: some View {
        HStack(spacing: 12) {
            AlertIconView(type: alert.type, size: 40)
                .overlay(
                    alignment: .topTrailing,
                    content: {
                        if !alert.isRead {
                            Circle()
                                .fill(Color.agriGreen)
                                .frame(width: 10, height: 10)
                                .offset(x: 2, y: -2)
                        }
                    }
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(alert.title)
                        .font(.subheadline)
                        .fontWeight(alert.isRead ? .regular : .semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(alert.scheduledDate.relativeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .opacity(alert.isRead ? 0.7 : 1.0)
    }
}

// MARK: - Seed Demo Alerts (for development / onboarding)
extension AlertViewModel {
    func seedDemoAlerts(userId: String) async {
        let demos: [(AlertType, String, String, Int)] = [
            (.watering, "Watering Due — Field A", "Paddy (Samba) requires irrigation. Day 45, tillering stage.", 0),
            (.disease, "Disease Risk — Field B", "High humidity detected. Blast risk elevated. Scan recommended.", 0),
            (.fertilizing, "Fertilizing Reminder", "Apply TSP for Red Chilli in Field C. Week 8 schedule.", -1),
            (.harvest, "Harvest Approaching", "Red Chilli in Field C approaching harvest window — 7 days.", -1),
            (.watering, "Morning Watering — Field D", "Big Onion crop in Field D needs irrigation.", -2)
        ]

        for (type, title, message, daysOffset) in demos {
            let alert = AgriAlert(
                userId: userId,
                type: type,
                title: title,
                message: message,
                cropLogId: nil,
                isRead: daysOffset < -1,
                scheduledDate: Date().addingTimeInterval(TimeInterval(daysOffset * 86400)),
                createdAt: Date().addingTimeInterval(TimeInterval(daysOffset * 86400))
            )
            try? await FirestoreService.shared.saveAlert(alert)
        }
    }
}
