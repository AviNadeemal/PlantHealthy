import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = InsightsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Search Bar
                SearchBar(text: $vm.searchText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Period filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InsightsViewModel.InsightPeriod.allCases, id: \.rawValue) { period in
                            FilterChip(title: period.rawValue, isActive: vm.selectedPeriod == period) {
                                vm.selectedPeriod = period
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }

                // Metric Cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    InsightMetricCard(
                        label: "Total Revenue",
                        value: vm.totalRevenue.lkrFormatted,
                        trend: "+18.3%",
                        trendUp: true,
                        color: .agriGreen,
                        chartData: [0.5, 0.7, 0.45, 0.9, 0.75, 1.0]
                    )
                    InsightMetricCard(
                        label: "Crop Cycles",
                        value: "\(vm.filteredLogs.count)",
                        trend: "+2 this season",
                        trendUp: true,
                        color: .blue,
                        chartData: [0.3, 0.5, 0.6, 0.4, 0.8, 0.7]
                    )
                    InsightMetricCard(
                        label: "Avg Profit/Acre",
                        value: vm.filteredLogs.isEmpty ? "—" :
                            (vm.totalRevenue / max(vm.filteredLogs.reduce(0) { $0 + $1.fieldSizeAcres }, 1)).lkrFormatted,
                        trend: "Per acre",
                        trendUp: true,
                        color: Color(hex: "#FF9F0A"),
                        chartData: [0.4, 0.6, 0.5, 0.8, 0.65, 0.9]
                    )
                    InsightMetricCard(
                        label: "Best Season",
                        value: "Maha",
                        trend: "2024/2025",
                        trendUp: true,
                        color: Color(hex: "#5856D6"),
                        chartData: [0.3, 0.7, 0.5, 1.0, 0.6, 0.8]
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Most Profitable Crops
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "🏆 Most Profitable Crops")

                    if vm.profitByCrop.isEmpty {
                        EmptyStateCard(icon: "chart.bar", message: "Not enough data yet.\nAdd crop logs and transactions to see insights.")
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(Array(vm.profitByCrop.prefix(5).enumerated()), id: \.offset) { index, item in
                            ProfitRankRow(rank: index + 1, cropName: item.cropName,
                                          profit: item.profit, count: item.count)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                // Seasonal Comparison
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "📅 All Crop Records")

                    if vm.filteredLogs.isEmpty {
                        EmptyStateCard(icon: "leaf.circle", message: "No crop records match your search or filter.")
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(vm.filteredLogs) { log in
                            InsightCropRow(cropLog: log)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.agriBackground)
        .navigationTitle("Historical Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let uid = authVM.currentUser?.uid else { return }
            Task { await vm.loadData(userId: uid) }
        }
    }
}

// MARK: - Insight Metric Card
struct InsightMetricCard: View {
    let label: String
    let value: String
    let trend: String
    let trendUp: Bool
    let color: Color
    let chartData: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 3) {
                Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text(trend).font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(trendUp ? color : .red)

            // Mini sparkline chart
            MiniSparkline(data: chartData, color: color)
                .frame(height: 28)
        }
        .padding(14)
        .background(Color.agriCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Mini Sparkline
struct MiniSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxVal = data.max() ?? 1
            let step = w / CGFloat(data.count - 1)

            ZStack(alignment: .bottom) {
                // Fill
                Path { path in
                    guard data.count > 1 else { return }
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, val) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(val / maxVal) * h)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.2), color.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))

                // Line
                Path { path in
                    guard data.count > 1 else { return }
                    for (i, val) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(val / maxVal) * h)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Profit Rank Row
struct ProfitRankRow: View {
    let rank: Int
    let cropName: String
    let profit: Double
    let count: Int

    var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD60A")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return Color.secondary.opacity(0.3)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(rankColor.opacity(0.2)).frame(width: 32, height: 32)
                Text("\(rank)").font(.system(size: 13, weight: .bold)).foregroundColor(rankColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cropName).font(.subheadline).fontWeight(.semibold)
                Text("\(count) transaction\(count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            Text(profit.lkrFormatted)
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(profit >= 0 ? Color(hex: "#30D158") : .red)
        }
        .padding(12)
        .background(Color.agriCard)
        .cornerRadius(12)
    }
}

// MARK: - Insight Crop Row
struct InsightCropRow: View {
    let cropLog: CropLog

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.agriGreen.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text(cropEmoji).font(.body)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cropLog.cropName).font(.subheadline).fontWeight(.semibold)
                Text("\(cropLog.fieldName) · \(cropLog.soilType.rawValue)")
                    .font(.caption).foregroundColor(.secondary)
                Text("Planted: \(cropLog.plantingDate.displayString)")
                    .font(.caption2).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: cropLog.status)
                Text("\(cropLog.fieldSizeAcres, specifier: "%.1f") ac")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.agriCard)
        .cornerRadius(12)
        .padding(.bottom, 4)
    }

    var cropEmoji: String {
        let l = cropLog.cropName.lowercased()
        if l.contains("paddy") || l.contains("rice") { return "🌾" }
        if l.contains("chilli") { return "🌶" }
        if l.contains("onion") { return "🧅" }
        if l.contains("tomato") { return "🍅" }
        if l.contains("maize") { return "🌽" }
        if l.contains("potato") { return "🥔" }
        return "🌿"
    }
}
