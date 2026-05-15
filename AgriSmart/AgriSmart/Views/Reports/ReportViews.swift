import SwiftUI
import FirebaseFirestore

// MARK: - Report List View
struct ReportListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var cropLogs: [CropLog] = []
    @State private var transactions: [FinancialTransaction] = []
    @State private var isLoading = true
    @State private var selectedLog: CropLog? = nil
    @State private var showPreview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Banner
                ZStack {
                    LinearGradient(colors: [Color(hex: "#32ADE6"), Color(hex: "#1C7FB5")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expert Reports").font(.title3).fontWeight(.bold).foregroundColor(.white)
                            Text("Generate & share PDF growth reports")
                                .font(.caption).foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Text("📄").font(.system(size: 44))
                    }
                    .padding(20)
                }
                .frame(height: 110)
                .cornerRadius(18)
                .padding(16)

                if isLoading {
                    ProgressView("Loading crop logs…")
                        .padding(40)
                } else if cropLogs.isEmpty {
                    EmptyStateCard(icon: "doc.text", message: "No crop logs found.\nAdd a crop log to generate your first report.")
                        .padding(16)
                } else {
                    SectionHeader(title: "Select a Crop to Report")

                    ForEach(cropLogs) { log in
                        Button {
                            selectedLog = log
                            showPreview = true
                        } label: {
                            ReportCropRow(cropLog: log)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color.agriBackground)
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
        .navigationDestination(isPresented: $showPreview) {
            if let log = selectedLog, let user = authVM.currentUser {
                ReportPreviewView(
                    report: GrowthReport(
                        user: user,
                        cropLog: log,
                        transactions: transactions.filter { $0.cropLogId == log.id }
                    )
                )
            }
        }
    }

    private func loadData() {
        guard let uid = authVM.currentUser?.uid else { return }
        Task {
            async let logs = FirestoreService.shared.fetchCropLogs(userId: uid)
            async let txns = FirestoreService.shared.fetchTransactions(userId: uid)
            do {
                let (l, t) = try await (logs, txns)
                await MainActor.run {
                    self.cropLogs = l
                    self.transactions = t
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

// MARK: - Report Crop Row
struct ReportCropRow: View {
    let cropLog: CropLog
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3).foregroundColor(Color(hex: "#32ADE6"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "#32ADE6").opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                Text(cropLog.cropName).font(.subheadline).fontWeight(.semibold)
                Text("\(cropLog.fieldName) · \(cropLog.plantingDate.displayString)")
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                StatusBadge(status: cropLog.status)
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.agriCard)
        .cornerRadius(14)
    }
}

// MARK: - Report Preview View
struct ReportPreviewView: View {
    let report: GrowthReport
    @State private var pdfURL: URL? = nil
    @State private var showShareSheet = false
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // PDF Preview Document
                VStack(spacing: 0) {
                    // Doc header
                    VStack(spacing: 0) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.agriGreen.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Text("🌱").font(.body)
                            }
                            Text("AgriSmart").font(.subheadline).fontWeight(.bold).foregroundColor(.agriGreen)
                            Spacer()
                            Text("CONFIDENTIAL").font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary).kerning(0.8)
                        }

                        Divider().padding(.vertical, 8)

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Crop Growth Report")
                                    .font(.title3).fontWeight(.bold)
                                Text("Generated: \(report.generatedDate.displayString)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.agriCard)

                    Divider()

                    // Farmer info section
                    ReportSection(title: "Farmer Information") {
                        ReportDataGrid(items: [
                            ("Name", report.user.fullName),
                            ("Mobile", report.user.mobile),
                            ("District", report.user.district),
                            ("Farm", report.user.farmName),
                            ("Farm Size", "\(report.user.farmSizeAcres) Acres")
                        ])
                    }

                    Divider()

                    // Crop info
                    ReportSection(title: "Crop Summary") {
                        ReportDataGrid(items: [
                            ("Crop", report.cropLog.cropName),
                            ("Variety", report.cropLog.variety.isEmpty ? "—" : report.cropLog.variety),
                            ("Field", report.cropLog.fieldName),
                            ("Field Size", "\(report.cropLog.fieldSizeAcres) Acres"),
                            ("Soil Type", report.cropLog.soilType.rawValue),
                            ("Planted", report.cropLog.plantingDate.displayString),
                            ("Exp. Harvest", report.cropLog.expectedHarvestDate.displayString),
                            ("Growth Stage", report.cropLog.growthStage.rawValue),
                            ("Status", report.cropLog.status.rawValue),
                            ("Progress", "\(Int(report.cropLog.progressPercent * 100))%")
                        ])
                    }

                    Divider()

                    // Financial
                    ReportSection(title: "Financial Overview") {
                        VStack(spacing: 8) {
                            ReportDataGrid(items: [
                                ("Total Income", report.totalIncome.lkrFormatted),
                                ("Total Expenses", report.totalExpenses.lkrFormatted),
                                ("Net Profit", report.netProfit.lkrFormatted)
                            ])

                            if !report.transactions.isEmpty {
                                Divider()
                                Text("Recent Transactions")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)

                                ForEach(report.transactions.prefix(5)) { txn in
                                    HStack {
                                        Text(txn.category.icon)
                                        Text(txn.description).font(.caption).foregroundColor(.primary)
                                        Spacer()
                                        Text("\(txn.type == .income ? "+" : "-")\(txn.amount.lkrFormatted)")
                                            .font(.caption).fontWeight(.semibold)
                                            .foregroundColor(txn.type == .income ? .green : .red)
                                    }
                                }
                            }
                        }
                    }

                    // Footer
                    HStack {
                        Text("AgriSmart — Smart Farming for Sri Lanka")
                            .font(.system(size: 9)).foregroundColor(.secondary)
                        Spacer()
                        Text("Page 1 of 1").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 14).padding(.top, 8)
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                .padding(.horizontal, 16)

                // Share options
                VStack(spacing: 10) {
                    SectionHeader(title: "Export Options")

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ShareOptionButton(icon: "logo.whatsapp", label: "WhatsApp", color: Color(hex: "#25D366")) {
                            generateAndShare()
                        }
                        ShareOptionButton(icon: "envelope.fill", label: "Email", color: .blue) {
                            generateAndShare()
                        }
                        ShareOptionButton(icon: "arrow.down.doc.fill", label: "Save PDF", color: .red) {
                            generateAndShare()
                        }
                        ShareOptionButton(icon: "square.and.arrow.up.fill", label: "More", color: .secondary) {
                            generateAndShare()
                        }
                    }
                    .padding(.horizontal, 16)
                }

                AgriButton(
                    title: isGenerating ? "Generating PDF…" : "Export via Share Sheet",
                    icon: "square.and.arrow.up",
                    isLoading: isGenerating
                ) {
                    generateAndShare()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
        .background(Color.agriBackground)
        .navigationTitle("Report Preview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func generateAndShare() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data = ReportService.shared.generatePDF(report: report)
            let filename = "AgriSmart_Report_\(report.cropLog.cropName)_\(DateFormatter.displayDate.string(from: report.generatedDate))"
            let url = ReportService.shared.saveTempPDF(data: data, filename: filename)
            DispatchQueue.main.async {
                self.isGenerating = false
                self.pdfURL = url
                self.showShareSheet = true
            }
        }
    }
}

// MARK: - Report Section
struct ReportSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.agriGreen)
                .textCase(.uppercase)
                .kerning(0.6)
                .padding(.top, 2)
            content()
        }
        .padding(16)
    }
}

// MARK: - Report Data Grid
struct ReportDataGrid: View {
    let items: [(String, String)]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.0) { label, value in
                HStack {
                    Text(label).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(value).font(.caption).fontWeight(.semibold).foregroundColor(.primary)
                }
                .padding(.vertical, 5)
                if label != items.last?.0 {
                    Divider()
                }
            }
        }
    }
}

// MARK: - Share Option Button
struct ShareOptionButton: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .cornerRadius(14)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
