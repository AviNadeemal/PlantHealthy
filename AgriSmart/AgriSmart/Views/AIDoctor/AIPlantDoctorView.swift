import SwiftUI

// MARK: - AI Plant Doctor Entry View
struct AIPlantDoctorView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = AIPlantDoctorViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showImageOptions = false
    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.showResult, let result = vm.diagnosisResult {
                    DiagnosisResultView(result: result, capturedImage: vm.capturedImage) {
                        vm.reset()
                    }
                } else {
                    cameraInterface
                }
            }
            .navigationTitle("AI Plant Doctor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if vm.showResult {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { vm.reset() } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $vm.capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(image: $vm.capturedImage, sourceType: .photoLibrary)
                .ignoresSafeArea()
        }
        .onChange(of: vm.capturedImage) { image in
            guard let image = image, let uid = authVM.currentUser?.uid else { return }
            vm.analyze(image: image, userId: uid)
        }
        .confirmationDialog("Select Image", isPresented: $showImageOptions, titleVisibility: .visible) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibrary = true }
        }
    }

    // MARK: - Camera Interface
    var cameraInterface: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Viewfinder
                ZStack {
                    Color(red: 0.05, green: 0.15, blue: 0.08).ignoresSafeArea()

                    if let img = vm.capturedImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .cornerRadius(12)
                            .padding(20)
                    } else {
                        VStack(spacing: 16) {
                            // Frame guides
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    .frame(width: 220, height: 220)

                                // Corner markers
                                ForEach(0..<4) { i in
                                    CornerBracket()
                                        .rotationEffect(.degrees(Double(i) * 90))
                                        .offset(
                                            x: [CGFloat(-110), 110, 110, -110][i],
                                            y: [CGFloat(-110), -110, 110, 110][i]
                                        )
                                }

                                Text("🍃").font(.system(size: 60)).opacity(0.4)
                            }

                            Text("Position leaf within the frame")
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                        }
                    }

                    // Analyzing overlay
                    if vm.isAnalyzing {
                        ZStack {
                            Color.black.opacity(0.6)
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                Text("Analyzing for diseases...")
                                    .font(.subheadline).foregroundColor(.white)
                                Text("Using AI to identify plant conditions")
                                    .font(.caption).foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .cornerRadius(16)
                    }
                }
                .frame(maxHeight: .infinity)

                // Controls
                VStack(spacing: 0) {
                    // Mode tabs
                    HStack(spacing: 30) {
                        ForEach(["PHOTO", "SCAN", "UPLOAD"], id: \.self) { mode in
                            Text(mode)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(mode == "SCAN" ? Color(hex: "#FFD60A") : .white.opacity(0.5))
                        }
                    }
                    .padding(.top, 12)

                    // Shutter row
                    HStack(spacing: 0) {
                        Spacer()
                        // Gallery
                        Button { showLibrary = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)).frame(width: 46, height: 46)
                                Image(systemName: "photo.on.rectangle").font(.title3).foregroundColor(.white)
                            }
                        }
                        Spacer()

                        // Shutter
                        Button { showCamera = true } label: {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.25)).frame(width: 76, height: 76)
                                Circle().fill(.white).frame(width: 64, height: 64)
                            }
                        }
                        Spacer()

                        // Flip camera
                        Button { } label: {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.15)).frame(width: 46, height: 46)
                                Image(systemName: "arrow.triangle.2.circlepath.camera").font(.title3).foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)

                    // Tips
                    HStack(spacing: 16) {
                        TipChip(icon: "sun.max", text: "Good lighting")
                        TipChip(icon: "scope", text: "Clear focus")
                        TipChip(icon: "crop", text: "Affected area")
                    }
                    .padding(.horizontal, 20).padding(.bottom, 16)
                }
                .background(Color.black)
            }
        }
    }
}

// MARK: - Corner Bracket
struct CornerBracket: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.agriGreen).frame(width: 20, height: 3)
            Rectangle().fill(Color.agriGreen).frame(width: 3, height: 20)
        }
    }
}

// MARK: - Tip Chip
struct TipChip: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2).foregroundColor(.white.opacity(0.7))
            Text(text).font(.caption2).foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.white.opacity(0.1)).cornerRadius(20)
    }
}

// MARK: - Diagnosis Result View
struct DiagnosisResultView: View {
    let result: DiagnosisResult
    let capturedImage: UIImage?
    let onReset: () -> Void
    @State private var showShareSheet = false

    var severityColor: Color {
        switch result.severity {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Image + Badge
                ZStack(alignment: .bottom) {
                    Group {
                        if let img = capturedImage {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: [Color(hex: "#1a3a1a"), Color(hex: "#2a5a2a")],
                                           startPoint: .top, endPoint: .bottom)
                        }
                    }
                    .frame(height: 200).clipped()

                    // Disease badge
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(result.diseaseName).font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "waveform.path.ecg").foregroundColor(.white.opacity(0.7))
                        }
                        HStack(spacing: 8) {
                            Text("Confidence: \(Int(result.confidence * 100))%")
                                .font(.caption).foregroundColor(.white.opacity(0.8))
                            ProgressView(value: result.confidence)
                                .tint(Color(hex: "#FF9F0A"))
                                .frame(maxWidth: 100)
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(0)
                }

                VStack(spacing: 16) {
                    // Severity Banner
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(severityColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Severity: \(result.severity.rawValue)").font(.subheadline)
                                .fontWeight(.bold).foregroundColor(severityColor)
                            Text(result.description).font(.caption).foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(severityColor.opacity(0.1))
                    .overlay(Rectangle().fill(severityColor).frame(width: 4), alignment: .leading)
                    .cornerRadius(10)

                    // Remedies
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Treatment Remedies", systemImage: "cross.case.fill")
                                .font(.subheadline).fontWeight(.bold).foregroundColor(.agriGreen)
                            ForEach(Array(result.remedies.enumerated()), id: \.offset) { i, remedy in
                                HStack(alignment: .top, spacing: 10) {
                                    ZStack {
                                        Circle().fill(Color.agriGreen).frame(width: 22, height: 22)
                                        Text("\(i + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                    }
                                    .padding(.top, 1)
                                    Text(remedy).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Prevention
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Prevention Tips", systemImage: "shield.checkerboard")
                                .font(.subheadline).fontWeight(.bold).foregroundColor(.blue)
                            ForEach(result.preventionTips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.caption)
                                        .padding(.top, 2)
                                    Text(tip).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        AgriButton(title: "Scan Again", icon: "camera.fill", style: .secondary) { onReset() }
                        AgriButton(title: "Consult Officer", icon: "phone.fill") {
                            guard let url = URL(string: "tel://+94112186000") else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .padding(16)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}
