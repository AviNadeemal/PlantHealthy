import SwiftUI

// MARK: - Color Theme
extension Color {
    static let agriGreen = Color(hex: "#2d8a4e")
    static let agriBackground = Color(UIColor.systemGroupedBackground)
    static let agriCard = Color(UIColor.secondarySystemGroupedBackground)
}

// MARK: - AgriSmart Primary Button
struct AgriButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var isLoading = false
    let action: () -> Void

    enum ButtonStyle { case primary, secondary, destructive }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    if let icon = icon { Image(systemName: icon) }
                    Text(title).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(bgColor)
            .foregroundColor(fgColor)
            .cornerRadius(14)
            .overlay(
                style == .secondary ?
                RoundedRectangle(cornerRadius: 14).stroke(Color.agriGreen, lineWidth: 1.5) : nil
            )
        }
        .disabled(isLoading)
    }

    private var bgColor: Color {
        switch style {
        case .primary: return .agriGreen
        case .secondary: return .clear
        case .destructive: return Color.red.opacity(0.1)
        }
    }
    private var fgColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .agriGreen
        case .destructive: return .red
        }
    }
}

// MARK: - iOS Grouped List Row
struct AgriListRow<Content: View>: View {
    var icon: String
    var iconColor: Color = .agriGreen
    var label: String
    var showChevron = true
    @ViewBuilder var trailing: () -> Content

    init(icon: String, iconColor: Color = .agriGreen, label: String,
         showChevron: Bool = true, @ViewBuilder trailing: @escaping () -> Content) {
        self.icon = icon; self.iconColor = iconColor; self.label = label
        self.showChevron = showChevron; self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(iconColor)
                .cornerRadius(7)
            Text(label).font(.body)
            Spacer()
            trailing()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    var value: String
    var label: String
    var icon: String? = nil
    var color: Color = .agriGreen

    var body: some View {
        VStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon).font(.title3).foregroundColor(color)
            }
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(.primary)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.agriCard)
        .cornerRadius(12)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            Spacer()
            if let action = action {
                Button(action: { onAction?() }) {
                    Text(action).font(.system(size: 13)).foregroundColor(.agriGreen)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - iOS Style Search Bar
struct SearchBar: View {
    @Binding var text: String
    var placeholder = "Search..."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.system(size: 15))
            TextField(placeholder, text: $text).font(.system(size: 15))
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(UIColor.systemFill))
        .cornerRadius(10)
    }
}

// MARK: - Crop Status Badge
struct StatusBadge: View {
    let status: CropStatus

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .cornerRadius(6)
    }

    var badgeColor: Color {
        switch status {
        case .growing: return .green
        case .readyToHarvest: return .orange
        case .harvested: return .secondary
        case .planned: return .blue
        case .failed: return .red
        }
    }
}

// MARK: - Alert Type Icon
struct AlertIconView: View {
    let type: AlertType
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: size * 0.45))
            .foregroundColor(iconColor)
            .frame(width: size, height: size)
            .background(iconColor.opacity(0.12))
            .cornerRadius(size * 0.28)
    }

    var iconColor: Color {
        switch type {
        case .watering: return .blue
        case .fertilizing: return .green
        case .disease: return .red
        case .harvest: return .orange
        case .general: return .secondary
        }
    }
}

// MARK: - Progress Ring
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6
    var size: CGFloat = 44
    var color: Color = .agriGreen

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - iOS-style Form Field
struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var keyboardType: UIKeyboardType = .default
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)
            if isSecure {
                SecureField(placeholder, text: $text).font(.body)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .font(.body)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ p: ImagePicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Currency Formatter
extension Double {
    var lkrFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "Rs. \(formatter.string(from: NSNumber(value: self)) ?? "0")"
    }
}

// MARK: - Date Helpers
extension Date {
    var displayString: String { DateFormatter.displayDate.string(from: self) }
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
