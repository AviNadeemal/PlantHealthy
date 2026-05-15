import SwiftUI
import PhotosUI

// MARK: - Crop Log List View
struct CropLogListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = CropLogViewModel()
    @State private var showEntry = false
    @State private var editingLog: CropLog? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                SearchBar(text: $vm.searchText).padding(.horizontal, 16).padding(.vertical, 8)

                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isActive: vm.filterStatus == nil) { vm.filterStatus = nil }
                        ForEach(CropStatus.allCases, id: \.rawValue) { status in
                            FilterChip(title: status.rawValue, isActive: vm.filterStatus == status) {
                                vm.filterStatus = vm.filterStatus == status ? nil : status
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }

                if vm.filteredLogs.isEmpty {
                    Spacer()
                    EmptyStateCard(icon: "leaf.circle", message: "No crop logs yet.\nTap + to start tracking your crops.")
                        .padding(.horizontal, 24)
                    Spacer()
                } else {
                    List {
                        ForEach(vm.filteredLogs) { log in
                            NavigationLink(destination: CropDetailView(cropLog: log, vm: vm)) {
                                CropLogRow(cropLog: log)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.agriBackground)
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                let log = vm.filteredLogs[i]
                                Task { await vm.delete(cropLog: log) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.agriBackground)
            .navigationTitle("Crop Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEntry = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundColor(.agriGreen)
                    }
                }
            }
            .sheet(isPresented: $showEntry) {
                NavigationStack { CropEntryFormView(cropLog: nil) }
            }
        }
        .onAppear {
            guard let uid = authVM.currentUser?.uid else { return }
            vm.startListening(userId: uid)
        }
        .onDisappear { vm.stopListening() }
    }
}

// MARK: - Crop Log Row
struct CropLogRow: View {
    let cropLog: CropLog
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.agriGreen.opacity(0.1)).frame(width: 44, height: 44)
                Text(cropEmoji(cropLog.cropName)).font(.title3)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(cropLog.cropName).font(.subheadline).fontWeight(.semibold)
                    if !cropLog.variety.isEmpty {
                        Text("(\(cropLog.variety))").font(.caption).foregroundColor(.secondary)
                    }
                }
                Text("\(cropLog.fieldName) · \(cropLog.soilType.rawValue)").font(.caption).foregroundColor(.secondary)
                Text("Planted \(cropLog.plantingDate.displayString)").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: cropLog.status)
                Text("Day \(cropLog.daysPlanted)").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    func cropEmoji(_ name: String) -> String {
        let l = name.lowercased()
        if l.contains("paddy") || l.contains("rice") { return "🌾" }
        if l.contains("chilli") { return "🌶" }
        if l.contains("onion") { return "🧅" }
        if l.contains("tomato") { return "🍅" }
        if l.contains("maize") { return "🌽" }
        if l.contains("potato") { return "🥔" }
        return "🌿"
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(isActive ? Color.agriGreen : Color.agriCard)
                .foregroundColor(isActive ? .white : .secondary)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(isActive ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - Crop Detail View
struct CropDetailView: View {
    let cropLog: CropLog
    @ObservedObject var vm: CropLogViewModel
    @State private var showEdit = false
    @State private var showPhotoOptions = false
    @State private var showImagePicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .camera
    @State private var selectedImage: UIImage?
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [Color(hex: "#1a5c2e"), Color(hex: "#3aab62")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 160)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cropLog.cropName).font(.title2).fontWeight(.bold).foregroundColor(.white)
                            if !cropLog.variety.isEmpty {
                                Text(cropLog.variety).font(.subheadline).foregroundColor(.white.opacity(0.75))
                            }
                            HStack(spacing: 6) {
                                StatusBadge(status: cropLog.status)
                                Text("· \(cropLog.fieldName)").font(.caption).foregroundColor(.white.opacity(0.75))
                            }
                        }
                        Spacer()
                        ProgressRing(progress: cropLog.progressPercent, lineWidth: 7, size: 60, color: .white)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 20)
                }

                // Photo Strip
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photos").font(.headline).padding(.horizontal, 16).padding(.top, 16)
                        Spacer()
                        Button { showPhotoOptions = true } label: {
                            Label("Add", systemImage: "plus").font(.subheadline).foregroundColor(.agriGreen)
                        }
                        .padding(.horizontal, 16).padding(.top, 16)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(cropLog.photoURLs, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color.secondary.opacity(0.15)
                                }
                                .frame(width: 80, height: 80).cornerRadius(12).clipped()
                            }
                            Button { showPhotoOptions = true } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.agriGreen.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    Image(systemName: "plus").font(.title3).foregroundColor(.agriGreen)
                                }
                                .frame(width: 80, height: 80)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .background(Color.agriCard)

                // Details
                LazyVStack(spacing: 0) {
                    SectionHeader(title: "Crop Details")
                    GroupBox {
                        VStack(spacing: 0) {
                            DetailRow(label: "Crop", value: cropLog.cropName)
                            Divider()
                            DetailRow(label: "Variety", value: cropLog.variety.isEmpty ? "—" : cropLog.variety)
                            Divider()
                            DetailRow(label: "Field", value: cropLog.fieldName)
                            Divider()
                            DetailRow(label: "Size", value: "\(cropLog.fieldSizeAcres) Acres")
                            Divider()
                            DetailRow(label: "Soil Type", value: cropLog.soilType.rawValue)
                            Divider()
                            DetailRow(label: "Growth Stage", value: cropLog.growthStage.rawValue)
                        }
                    }
                    .padding(.horizontal, 16)

                    SectionHeader(title: "Schedule")
                    GroupBox {
                        VStack(spacing: 0) {
                            DetailRow(label: "Planted", value: cropLog.plantingDate.displayString)
                            Divider()
                            DetailRow(label: "Expected Harvest", value: cropLog.expectedHarvestDate.displayString)
                            Divider()
                            DetailRow(label: "Days Elapsed", value: "\(cropLog.daysPlanted) of \(cropLog.totalDays) days")
                        }
                    }
                    .padding(.horizontal, 16)

                    if !cropLog.notes.isEmpty {
                        SectionHeader(title: "Notes")
                        GroupBox {
                            Text(cropLog.notes).font(.body).foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(cropLog.cropName)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack { CropEntryFormView(cropLog: cropLog) }
        }
        .confirmationDialog("Add Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") { pickerSource = .camera; showImagePicker = true }
            Button("Choose from Library") { pickerSource = .photoLibrary; showImagePicker = true }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: pickerSource)
        }
        .onChange(of: selectedImage) { img in
            guard let img = img, let uid = authVM.currentUser?.uid, let cid = cropLog.id else { return }
            guard let data = img.jpegData(compressionQuality: 0.8) else { return }
            Task { _ = try? await vm.uploadPhoto(userId: uid, cropLogId: cid, imageData: data) }
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium).foregroundColor(.primary)
        }
        .padding(.vertical, 10).padding(.horizontal, 4)
    }
}

// MARK: - Crop Entry Form View
struct CropEntryFormView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = CropLogViewModel()

    let cropLog: CropLog?

    @State private var cropName = ""
    @State private var variety = ""
    @State private var fieldName = ""
    @State private var fieldSize = ""
    @State private var soilType: SoilType = .clayLoam
    @State private var growthStage: GrowthStage = .seedling
    @State private var status: CropStatus = .growing
    @State private var plantingDate = Date()
    @State private var harvestDate = Date().addingTimeInterval(90 * 86400)
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMsg: String?

    var isEditing: Bool { cropLog != nil }

    var body: some View {
        Form {
            Section("Crop Information") {
                TextField("Crop Name (e.g. Paddy)", text: $cropName)
                TextField("Variety (e.g. Samba)", text: $variety)
                Picker("Crop Type", selection: $cropName) {
                    ForEach(CropType.allCases, id: \.rawValue) {
                        Text("\($0.icon) \($0.rawValue)").tag($0.rawValue)
                    }
                }
            }

            Section("Field Details") {
                TextField("Field Name (e.g. Field A)", text: $fieldName)
                HStack {
                    TextField("Field Size", text: $fieldSize)
                        .keyboardType(.decimalPad)
                    Text("Acres").foregroundColor(.secondary)
                }
                Picker("Soil Type", selection: $soilType) {
                    ForEach(SoilType.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                }
            }

            Section("Growth Information") {
                Picker("Growth Stage", selection: $growthStage) {
                    ForEach(GrowthStage.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                }
                Picker("Status", selection: $status) {
                    ForEach(CropStatus.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                }
            }

            Section("Schedule") {
                DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
                DatePicker("Expected Harvest", selection: $harvestDate, displayedComponents: .date)
            }

            Section("Notes") {
                TextEditor(text: $notes).frame(minHeight: 80)
            }

            if let err = errorMsg {
                Section {
                    Text(err).foregroundColor(.red).font(.caption)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Crop Log" : "New Crop Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") { saveCrop() }
                    .disabled(isSaving || cropName.isEmpty || fieldName.isEmpty)
                    .fontWeight(.semibold)
            }
        }
        .onAppear { populateFields() }
    }

    private func populateFields() {
        guard let log = cropLog else { return }
        cropName = log.cropName; variety = log.variety; fieldName = log.fieldName
        fieldSize = "\(log.fieldSizeAcres)"; soilType = log.soilType
        growthStage = log.growthStage; status = log.status
        plantingDate = log.plantingDate; harvestDate = log.expectedHarvestDate; notes = log.notes
    }

    private func saveCrop() {
        guard let uid = authVM.currentUser?.uid else { return }
        isSaving = true
        let log = CropLog(
            id: cropLog?.id,
            userId: uid,
            cropName: cropName,
            variety: variety,
            fieldName: fieldName,
            fieldSizeAcres: Double(fieldSize) ?? 0,
            soilType: soilType,
            plantingDate: plantingDate,
            expectedHarvestDate: harvestDate,
            growthStage: growthStage,
            status: status,
            notes: notes,
            photoURLs: cropLog?.photoURLs ?? [],
            latitude: nil, longitude: nil,
            createdAt: cropLog?.createdAt ?? Date(),
            updatedAt: Date()
        )
        Task {
            do {
                _ = try await vm.saveCropLog(log)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription; isSaving = false }
            }
        }
    }
}
