import SwiftUI

struct CalculatorView: View {
    @State private var selectedCrop: CropType = .paddy
    @State private var landSizeAcres: Double = 1.0
    @State private var selectedSoil: SoilType = .clayLoam
    @State private var result: CropInputRequirement?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header banner
                ZStack {
                    LinearGradient(colors: [Color(hex: "#5856D6"), Color(hex: "#7B79E8")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Smart Input Calculator")
                                .font(.title3).fontWeight(.bold).foregroundColor(.white)
                            Text("Calculate seeds, fertilizer & water needs")
                                .font(.caption).foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Text("⚖️").font(.system(size: 44))
                    }
                    .padding(20)
                }
                .frame(height: 110)
                .cornerRadius(18)
                .padding(.horizontal, 16)

                // Crop Selector
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Select Crop")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(CropType.allCases, id: \.rawValue) { crop in
                                CropTypeButton(
                                    crop: crop,
                                    isSelected: selectedCrop == crop
                                ) { selectedCrop = crop; calculate() }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Land Size Stepper
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Land Size", systemImage: "ruler.fill")
                            .font(.subheadline).fontWeight(.semibold)

                        HStack(spacing: 16) {
                            Button {
                                if landSizeAcres > 0.5 { landSizeAcres -= 0.5; calculate() }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title).foregroundColor(Color(hex: "#5856D6"))
                            }

                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", landSizeAcres))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                Text("Acres").font(.caption).foregroundColor(.secondary)
                            }
                            .frame(minWidth: 90)

                            Button {
                                if landSizeAcres < 50 { landSizeAcres += 0.5; calculate() }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title).foregroundColor(Color(hex: "#5856D6"))
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Slider(value: $landSizeAcres, in: 0.5...50, step: 0.5)
                            .tint(Color(hex: "#5856D6"))
                            .onChange(of: landSizeAcres) { _ in calculate() }

                        HStack {
                            Text("0.5 Acres").font(.caption2).foregroundColor(.secondary)
                            Spacer()
                            Text("50 Acres").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Soil Type
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Soil Type", systemImage: "square.stack.3d.down.right.fill")
                            .font(.subheadline).fontWeight(.semibold)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(SoilType.allCases, id: \.rawValue) { soil in
                                Button {
                                    selectedSoil = soil; calculate()
                                } label: {
                                    Text(soil.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, 8).padding(.horizontal, 4)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedSoil == soil ? Color(hex: "#5856D6") : Color.agriCard)
                                        .foregroundColor(selectedSoil == soil ? .white : .primary)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedSoil == soil ? Color.clear : Color.secondary.opacity(0.2)))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Results
                if let r = result {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "📊 Required Resources")

                        VStack(spacing: 0) {
                            CalcResultRow(icon: "🌱", label: "Seeds Required",
                                          value: String(format: "%.1f kg", r.seedsKg),
                                          isLast: false)
                            CalcResultRow(icon: "🧪", label: "Urea Fertilizer",
                                          value: String(format: "%.1f kg", r.ureaKg),
                                          isLast: false)
                            CalcResultRow(icon: "🌿", label: "TSP (Phosphate)",
                                          value: String(format: "%.1f kg", r.tspKg),
                                          isLast: false)
                            CalcResultRow(icon: "⚗️", label: "Muriate of Potash",
                                          value: String(format: "%.1f kg", r.muriatePotashKg),
                                          isLast: false)
                            CalcResultRow(icon: "💧", label: "Water per Day",
                                          value: String(format: "%.0f L", r.waterLitersPerDay),
                                          isLast: false)
                            CalcResultRow(icon: "💰", label: "Est. Input Cost",
                                          value: r.estimatedCostLKR.lkrFormatted,
                                          isLast: true, highlight: true)
                        }
                        .background(Color.agriCard)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.12)))
                        .padding(.horizontal, 16)

                        // Disclaimer
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle").font(.caption).foregroundColor(.secondary)
                            Text("Values based on Sri Lanka DoA recommendations. Adjust based on local conditions and soil test results.")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                }

                AgriButton(title: "Calculate Requirements", icon: "function") {
                    calculate()
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Color.agriBackground)
        .navigationTitle("Input Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calculate() }
    }

    private func calculate() {
        withAnimation(.easeInOut) {
            result = CropInputRequirement.calculate(crop: selectedCrop, acres: landSizeAcres, soil: selectedSoil)
        }
    }
}

// MARK: - Crop Type Button
struct CropTypeButton: View {
    let crop: CropType; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(crop.icon).font(.title2)
                    .frame(width: 52, height: 52)
                    .background(isSelected ? Color(hex: "#5856D6") : Color.agriCard)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2)))
                Text(crop.rawValue).font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#5856D6") : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Calc Result Row
struct CalcResultRow: View {
    let icon: String; let label: String; let value: String
    var isLast: Bool = false; var highlight: Bool = false
    var body: some View {
        HStack {
            Text(icon).font(.body)
            Text(label).font(.subheadline).foregroundColor(.primary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.bold)
                .foregroundColor(highlight ? Color(hex: "#5856D6") : .primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(highlight ? Color(hex: "#5856D6").opacity(0.06) : Color.clear)
        if !isLast { Divider().padding(.leading, 44) }
    }
}
