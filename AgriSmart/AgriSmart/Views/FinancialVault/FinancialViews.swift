import SwiftUI
import Charts

// MARK: - Financial Vault (Locked Entry)
struct FinancialVaultView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = FinancialViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isVaultUnlocked {
                    ProfitTrackerDashboard(vm: vm)
                } else {
                    VaultLockedView {
                        Task { _ = await vm.unlockVault() }
                    }
                }
            }
            .navigationTitle("Financial Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                if vm.isVaultUnlocked {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { vm.isVaultUnlocked = false } label: {
                            Image(systemName: "lock").foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard let uid = authVM.currentUser?.uid else { return }
            vm.startListening(userId: uid)
        }
        .onDisappear { vm.stopListening() }
    }
}

// MARK: - Vault Locked View
struct VaultLockedView: View {
    let onUnlock: () -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Color.agriGreen.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulse ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60)).foregroundColor(.agriGreen)
                }
                .onAppear { pulse = true }

                VStack(spacing: 8) {
                    Text("Financial Vault").font(.title2).fontWeight(.bold)
                    Text("Your financial records are encrypted and protected.\nAuthenticate to access your data.")
                        .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                }

                Button(action: onUnlock) {
                    VStack(spacing: 8) {
                        Image(systemName: BiometricAuthService.shared.biometricType == .faceID ? "faceid" : "touchid")
                            .font(.system(size: 40))
                        Text("Unlock with \(BiometricAuthService.shared.biometricTypeName)")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("or use your passcode").font(.caption).foregroundColor(.secondary)
                    }
                    .frame(width: 200, height: 120)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.agriGreen.opacity(0.2), lineWidth: 1))
                }
                .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Secured with iOS Secure Enclave").font(.caption).foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Profit Tracker Dashboard
struct ProfitTrackerDashboard: View {
    @ObservedObject var vm: FinancialViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showAddTransaction = false
    @State private var filterType: TransactionType? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Summary Header
                ZStack {
                    LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("Net Profit · 2025").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text(vm.netProfit.lkrFormatted)
                                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                            HStack(spacing: 4) {
                                Image(systemName: vm.netProfit >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(vm.netProfit >= 0 ? "Profitable Season" : "Net Loss")
                            }
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(vm.netProfit >= 0 ? Color(hex: "#30D158") : .red)
                        }

                        // Mini bar chart
                        if !vm.monthlyData.isEmpty {
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(vm.monthlyData, id: \.month) { data in
                                    VStack(spacing: 4) {
                                        let maxVal = vm.monthlyData.map { max($0.income, $0.expense) }.max() ?? 1
                                        let incomeH = CGFloat(data.income / maxVal) * 44
                                        let expenseH = CGFloat(data.expense / maxVal) * 44
                                        HStack(alignment: .bottom, spacing: 2) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(hex: "#30D158").opacity(0.8))
                                                .frame(width: 8, height: max(incomeH, 3))
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.red.opacity(0.7))
                                                .frame(width: 8, height: max(expenseH, 3))
                                        }
                                        Text(data.month).font(.system(size: 8)).foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .frame(height: 60)
                        }
                    }
                    .padding(20)
                }
                .frame(height: 200)

                // Income / Expense summary cards
                HStack(spacing: 12) {
                    FinanceSummaryCard(title: "Income", amount: vm.totalIncome, color: Color(hex: "#30D158"), icon: "arrow.up.circle.fill")
                    FinanceSummaryCard(title: "Expenses", amount: vm.totalExpenses, color: .red, icon: "arrow.down.circle.fill")
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                // Filter tabs
                HStack(spacing: 8) {
                    FilterChip(title: "All", isActive: filterType == nil) { filterType = nil }
                    FilterChip(title: "Income", isActive: filterType == .income) { filterType = .income }
                    FilterChip(title: "Expenses", isActive: filterType == .expense) { filterType = .expense }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 8)

                // Transaction list
                VStack(spacing: 0) {
                    let filtered = vm.transactions.filter { filterType == nil || $0.type == filterType }
                    if filtered.isEmpty {
                        EmptyStateCard(icon: "banknote", message: "No transactions yet.\nTap + to add income or expenses.")
                            .padding(.horizontal, 16).padding(.top, 12)
                    } else {
                        ForEach(filtered) { txn in
                            TransactionRow(transaction: txn)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteTransaction(txn) }
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddTransaction = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            NavigationStack {
                AddTransactionView(vm: vm)
            }
        }
    }
}

// MARK: - Finance Summary Card
struct FinanceSummaryCard: View {
    let title: String; let amount: Double; let color: Color; let icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(amount.lkrFormatted).font(.subheadline).fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: FinancialTransaction
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(transaction.type == .income ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(transaction.category.icon).font(.body)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description).font(.subheadline).fontWeight(.medium)
                Text("\(transaction.category.rawValue) · \(transaction.date.displayString)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(transaction.type == .income ? "+" : "-")\(transaction.amount.lkrFormatted)")
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(transaction.type == .income ? Color(hex: "#30D158") : .red)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.agriCard)
        Divider().padding(.leading, 68)
    }
}

// MARK: - Add Transaction View
struct AddTransactionView: View {
    @ObservedObject var vm: FinancialViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var type: TransactionType = .income
    @State private var category: TransactionCategory = .harvestSale
    @State private var amount = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var isSaving = false

    var incomeCategories: [TransactionCategory] { [.harvestSale, .subsidyPayment, .otherIncome] }
    var expenseCategories: [TransactionCategory] { [.seeds, .fertilizer, .pesticide, .labor, .equipment, .irrigation, .otherExpense] }
    var categories: [TransactionCategory] { type == .income ? incomeCategories : expenseCategories }

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $type) {
                    ForEach(TransactionType.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: type) { _ in
                    category = type == .income ? .harvestSale : .seeds
                }
            }

            Section("Details") {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.rawValue) {
                        Text("\($0.icon) \($0.rawValue)").tag($0)
                    }
                }
                HStack {
                    Text("Rs.").foregroundColor(.secondary)
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                }
                TextField("Description", text: $description)
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
        }
        .navigationTitle("Add Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") { saveTransaction() }
                    .fontWeight(.semibold)
                    .disabled(amount.isEmpty || description.isEmpty || isSaving)
            }
        }
    }

    private func saveTransaction() {
        guard let uid = authVM.currentUser?.uid, let amountVal = Double(amount) else { return }
        isSaving = true
        let txn = FinancialTransaction(
            userId: uid, type: type, category: category, amount: amountVal,
            description: description, cropLogId: nil, date: date, receiptURL: nil, createdAt: Date())
        Task {
            try? await vm.saveTransaction(txn)
            await MainActor.run { dismiss() }
        }
    }
}
