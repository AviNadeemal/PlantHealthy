import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import SwiftUI

// MARK: - AuthViewModel
class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService = FirebaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() { checkAuthState() }

    func checkAuthState() {
        if let uid = Auth.auth().currentUser?.uid {
            Task {
                do {
                    let user = try await authService.fetchUser(uid: uid)
                    await MainActor.run {
                        self.currentUser = user
                        self.isLoggedIn = true
                    }
                } catch { await MainActor.run { self.isLoggedIn = false } }
            }
        }
    }

    func login(mobile: String, password: String) async {
        await setLoading(true)
        do {
            let user = try await authService.login(mobile: mobile, password: password)
            await MainActor.run { self.currentUser = user; self.isLoggedIn = true }
        } catch { await setError(error.localizedDescription) }
        await setLoading(false)
    }

    func signUp(fullName: String, mobile: String, district: String, farmName: String,
                farmSize: Double, primaryCrop: String, password: String) async {
        await setLoading(true)
        do {
            let user = try await authService.signUpWithMobile(
                mobile: mobile, password: password, fullName: fullName,
                district: district, farmName: farmName, farmSize: farmSize, primaryCrop: primaryCrop)
            await MainActor.run { self.currentUser = user; self.isLoggedIn = true }
            await NotificationManager.shared.requestPermission()
        } catch { await setError(error.localizedDescription) }
        await setLoading(false)
    }

    func logout() {
        try? authService.logout()
        currentUser = nil
        isLoggedIn = false
    }

    func resetPassword(mobile: String) async {
        await setLoading(true)
        do { try await authService.resetPassword(mobile: mobile) }
        catch { await setError(error.localizedDescription) }
        await setLoading(false)
    }

    func updateProfile(data: [String: Any]) async {
        guard let uid = currentUser?.uid else { return }
        do {
            try await authService.updateUser(uid: uid, data: data)
            let updated = try await authService.fetchUser(uid: uid)
            await MainActor.run { self.currentUser = updated }
        } catch { await setError(error.localizedDescription) }
    }

    @MainActor private func setLoading(_ v: Bool) { isLoading = v }
    @MainActor private func setError(_ msg: String) { errorMessage = msg }
}

// MARK: - CropLogViewModel
class CropLogViewModel: ObservableObject {
    @Published var cropLogs: [CropLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var filterStatus: CropStatus? = nil

    private let db = FirestoreService.shared
    private var listener: ListenerRegistration?

    var filteredLogs: [CropLog] {
        cropLogs.filter { log in
            let matchesSearch = searchText.isEmpty ||
                log.cropName.localizedCaseInsensitiveContains(searchText) ||
                log.fieldName.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterStatus == nil || log.status == filterStatus
            return matchesSearch && matchesFilter
        }
    }

    func startListening(userId: String) {
        listener = db.listenToCropLogs(userId: userId) { [weak self] logs in
            DispatchQueue.main.async { self?.cropLogs = logs }
        }
    }

    func stopListening() { listener?.remove() }

    func saveCropLog(_ log: CropLog) async throws -> String {
        let id = try await db.saveCropLog(log)
        if var updatedLog = cropLogs.first(where: { $0.id == log.id }) {
            updatedLog = log
        }
        // Schedule notifications for new crop
        NotificationManager.shared.scheduleGrowthCycleAlerts(for: log)
        return id
    }

    func delete(cropLog: CropLog) async {
        guard let id = cropLog.id else { return }
        do {
            try await db.deleteCropLog(id: id)
            NotificationManager.shared.cancelAlerts(for: cropLog)
        } catch { print("Delete error: \(error)") }
    }

    func uploadPhoto(userId: String, cropLogId: String, imageData: Data) async throws -> String {
        try await db.uploadCropPhoto(userId: userId, cropLogId: cropLogId, imageData: imageData)
    }
}

// MARK: - AIPlantDoctorViewModel
class AIPlantDoctorViewModel: ObservableObject {
    @Published var diagnosisResult: DiagnosisResult?
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var capturedImage: UIImage?
    @Published var showCamera = false
    @Published var showResult = false

    private let service = PlantDiseaseService.shared
    private let db = FirestoreService.shared

    func analyze(image: UIImage, userId: String) {
        isAnalyzing = true
        errorMessage = nil
        service.classify(image: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                switch result {
                case .success(let diagnosis):
                    self?.diagnosisResult = diagnosis
                    self?.showResult = true
                    Task { try? await self?.db.saveDiagnosis(userId: userId, result: diagnosis, imageURL: nil) }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func reset() {
        diagnosisResult = nil; capturedImage = nil
        showResult = false; errorMessage = nil
    }
}

// MARK: - FinancialViewModel
class FinancialViewModel: ObservableObject {
    @Published var transactions: [FinancialTransaction] = []
    @Published var isVaultUnlocked = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = FirestoreService.shared
    private var listener: ListenerRegistration?

    var totalIncome: Double { transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount } }
    var totalExpenses: Double { transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount } }
    var netProfit: Double { totalIncome - totalExpenses }

    var monthlyData: [(month: String, income: Double, expense: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { txn -> String in
            let components = calendar.dateComponents([.year, .month], from: txn.date)
            return "\(components.year ?? 0)-\(String(format: "%02d", components.month ?? 0))"
        }
        return grouped.sorted { $0.key < $1.key }.suffix(6).map { key, txns in
            let parts = key.split(separator: "-")
            let monthNum = Int(parts.last ?? "1") ?? 1
            let monthName = DateFormatter().monthSymbols[monthNum - 1].prefix(3).description
            return (
                month: monthName,
                income: txns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                expense: txns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            )
        }
    }

    func unlockVault() async -> Bool {
        let success = await BiometricAuthService.shared.authenticateForVault()
        await MainActor.run { isVaultUnlocked = success }
        return success
    }

    func startListening(userId: String) {
        listener = db.listenToTransactions(userId: userId) { [weak self] txns in
            DispatchQueue.main.async { self?.transactions = txns }
        }
    }

    func stopListening() { listener?.remove() }

    func saveTransaction(_ transaction: FinancialTransaction) async throws {
        isLoading = true
        defer { isLoading = false }
        _ = try await db.saveTransaction(transaction)
    }

    func deleteTransaction(_ transaction: FinancialTransaction) async {
        guard let id = transaction.id else { return }
        try? await db.deleteTransaction(id: id)
    }
}

// MARK: - AlertViewModel
class AlertViewModel: ObservableObject {
    @Published var alerts: [AgriAlert] = []
    @Published var errorMessage: String?

    private let db = FirestoreService.shared
    private var listener: ListenerRegistration?

    var unreadCount: Int { alerts.filter { !$0.isRead }.count }

    func startListening(userId: String) {
        listener = db.listenToAlerts(userId: userId) { [weak self] alerts in
            DispatchQueue.main.async { self?.alerts = alerts }
        }
    }

    func stopListening() { listener?.remove() }

    func markRead(_ alert: AgriAlert) async {
        guard let id = alert.id else { return }
        try? await db.markAlertRead(id: id)
    }

    func markAllRead() async {
        for alert in alerts where !alert.isRead {
            await markRead(alert)
        }
    }
}

// MARK: - ServiceLocatorViewModel
class ServiceLocatorViewModel: ObservableObject {
    @Published var services: [AgriService] = []
    @Published var selectedType: ServiceType? = nil
    @Published var isLoading = false
    @Published var selectedService: AgriService?

    private let db = FirestoreService.shared

    var filteredServices: [AgriService] {
        guard let type = selectedType else { return services }
        return services.filter { $0.type == type }
    }

    // Seeded mock services (replace with Firestore data)
    func loadServices() {
        services = [
            AgriService(id: "1", name: "Kurunegala Govijana Seva", type: .govijanaSeva,
                        address: "Puttalam Rd, Kurunegala", district: "Kurunegala",
                        latitude: 7.4863, longitude: 80.3647, phone: "037-2222301", openingHours: "8:00 AM – 4:30 PM", isOpen: true),
            AgriService(id: "2", name: "Dambulla Economic Centre", type: .market,
                        address: "Kandy Rd, Dambulla", district: "Matale",
                        latitude: 7.8668, longitude: 80.6519, phone: "066-2284700", openingHours: "4:00 AM – 12:00 PM", isOpen: true),
            AgriService(id: "3", name: "Colombo Manning Market", type: .market,
                        address: "Manning Pl, Colombo 01", district: "Colombo",
                        latitude: 6.9271, longitude: 79.8612, phone: "011-2431157", openingHours: "3:00 AM – 10:00 AM", isOpen: false),
            AgriService(id: "4", name: "Anuradhapura Govijana Seva", type: .govijanaSeva,
                        address: "Maithripala Mw, Anuradhapura", district: "Anuradhapura",
                        latitude: 8.3114, longitude: 80.4037, phone: "025-2222437", openingHours: "8:00 AM – 4:30 PM", isOpen: true),
            AgriService(id: "5", name: "Agrarian Services Bank – Kurunegala", type: .bank,
                        address: "Colombo Rd, Kurunegala", district: "Kurunegala",
                        latitude: 7.4875, longitude: 80.3620, phone: "037-2224500", openingHours: "9:00 AM – 3:00 PM", isOpen: true),
            AgriService(id: "6", name: "Lanka Agro Supplies", type: .supplier,
                        address: "Main St, Nikaweratiya", district: "Kurunegala",
                        latitude: 7.7279, longitude: 80.1176, phone: "037-2260000", openingHours: "8:00 AM – 6:00 PM", isOpen: true),
        ]
    }
}

// MARK: - InsightsViewModel
class InsightsViewModel: ObservableObject {
    @Published var cropLogs: [CropLog] = []
    @Published var transactions: [FinancialTransaction] = []
    @Published var selectedPeriod: InsightPeriod = .sixMonths
    @Published var searchText = ""

    enum InsightPeriod: String, CaseIterable {
        case oneMonth = "1M"; case threeMonths = "3M"
        case sixMonths = "6M"; case oneYear = "1Y"; case all = "All"
        var days: Int {
            switch self {
            case .oneMonth: return 30; case .threeMonths: return 90
            case .sixMonths: return 180; case .oneYear: return 365; case .all: return 99999
            }
        }
    }

    var filteredLogs: [CropLog] {
        let cutoff = Date().addingTimeInterval(-TimeInterval(selectedPeriod.days * 86400))
        return cropLogs.filter { log in
            log.plantingDate > cutoff &&
            (searchText.isEmpty || log.cropName.localizedCaseInsensitiveContains(searchText) ||
             log.fieldName.localizedCaseInsensitiveContains(searchText))
        }
    }

    var profitByCrop: [(cropName: String, profit: Double, count: Int)] {
        let grouped = Dictionary(grouping: transactions) { $0.cropLogId ?? "unknown" }
        return cropLogs.compactMap { log -> (String, Double, Int)? in
            guard let id = log.id else { return nil }
            let txns = grouped[id] ?? []
            let income = txns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let expense = txns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            return (log.cropName, income - expense, txns.count)
        }
        .filter { $0.1 != 0 }
        .sorted { $0.1 > $1.1 }
    }

    var totalRevenue: Double { transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount } }

    func loadData(userId: String) async {
        do {
            async let logs = FirestoreService.shared.fetchCropLogs(userId: userId)
            async let txns = FirestoreService.shared.fetchTransactions(userId: userId)
            let (l, t) = try await (logs, txns)
            await MainActor.run { self.cropLogs = l; self.transactions = t }
        } catch { print("Insights load error: \(error)") }
    }
}
