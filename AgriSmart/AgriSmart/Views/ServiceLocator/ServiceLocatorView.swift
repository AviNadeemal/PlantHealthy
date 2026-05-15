import SwiftUI
import MapKit

// MARK: - Service Locator View
struct ServiceLocatorView: View {
    @StateObject private var vm = ServiceLocatorViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 7.8731, longitude: 80.7718),
        span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
    )
    @State private var mapStyle: MapStyle = .standard
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Map
                Map(coordinateRegion: $region,
                    showsUserLocation: true,
                    annotationItems: vm.filteredServices) { service in
                    MapAnnotation(coordinate: service.coordinate) {
                        ServiceMapPin(service: service, isSelected: vm.selectedService?.id == service.id) {
                            vm.selectedService = service
                            showDetail = true
                            withAnimation {
                                region.center = service.coordinate
                            }
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Bottom sheet
                VStack(spacing: 0) {
                    // Filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isActive: vm.selectedType == nil) {
                                vm.selectedType = nil
                            }
                            ForEach(ServiceType.allCases, id: \.rawValue) { type in
                                FilterChip(title: type.rawValue, isActive: vm.selectedType == type) {
                                    vm.selectedType = vm.selectedType == type ? nil : type
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .background(.ultraThinMaterial)

                    // Selected service card
                    if let selected = vm.selectedService, showDetail {
                        ServiceDetailCard(service: selected) { showDetail = false; vm.selectedService = nil }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(), value: showDetail)
            }
            .navigationTitle("Service Locator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        mapStyle = mapStyle == .standard ? .hybrid : .standard
                    } label: {
                        Image(systemName: "map").foregroundColor(.agriGreen)
                    }
                }
            }
        }
        .onAppear { vm.loadServices() }
    }
}

// MARK: - Service Map Pin
struct ServiceMapPin: View {
    let service: AgriService
    let isSelected: Bool
    let onTap: () -> Void

    var pinColor: Color {
        switch service.type {
        case .govijanaSeva: return .agriGreen
        case .market: return .orange
        case .supplier: return .blue
        case .bank: return .purple
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(pinColor)
                        .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                        .shadow(color: pinColor.opacity(0.4), radius: 4, y: 2)
                    Image(systemName: service.type.icon)
                        .font(.system(size: isSelected ? 18 : 14))
                        .foregroundColor(.white)
                }

                // Pointer
                Triangle().fill(pinColor).frame(width: 12, height: 8)

                if isSelected {
                    Text(service.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(pinColor)
                        .cornerRadius(6)
                        .fixedSize()
                }
            }
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Service Detail Card
struct ServiceDetailCard: View {
    let service: AgriService
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 36, height: 4).padding(.top, 8)

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(serviceColor.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: service.type.icon).font(.title3).foregroundColor(serviceColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name).font(.subheadline).fontWeight(.bold)
                    Text(service.address).font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Circle().fill(service.isOpen == true ? Color.green : Color.red).frame(width: 6, height: 6)
                        Text(service.isOpen == true ? "Open Now" : "Closed")
                            .font(.caption).foregroundColor(service.isOpen == true ? .green : .red)
                        if let hours = service.openingHours {
                            Text("· \(hours)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.secondary)
                }
            }
            .padding(16)

            HStack(spacing: 10) {
                if let phone = service.phone {
                    Button {
                        guard let url = URL(string: "tel://\(phone.replacingOccurrences(of: "-", with: ""))") else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(Color.agriGreen.opacity(0.1)).cornerRadius(10)
                            .foregroundColor(.agriGreen).font(.subheadline.bold())
                    }
                }

                Button {
                    let coord = service.coordinate
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
                    item.name = service.name
                    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                } label: {
                    Label("Navigate", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.blue).cornerRadius(10)
                        .foregroundColor(.white).font(.subheadline.bold())
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 20)
        }
        .background(.regularMaterial)
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }

    var serviceColor: Color {
        switch service.type {
        case .govijanaSeva: return .agriGreen
        case .market: return .orange
        case .supplier: return .blue
        case .bank: return .purple
        }
    }
}

// MARK: - Round Specific Corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat; var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - MapStyle enum fix
enum MapStyle { case standard, hybrid }
