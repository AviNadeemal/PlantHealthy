import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - User Model
struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var uid: String
    var fullName: String
    var mobile: String
    var email: String?
    var district: String
    var farmName: String
    var farmSizeAcres: Double
    var primaryCropType: String
    var createdAt: Date
    var fcmToken: String?

    enum CodingKeys: String, CodingKey {
        case id, uid, fullName, mobile, email, district
        case farmName, farmSizeAcres, primaryCropType, createdAt, fcmToken
    }
}

// MARK: - Crop Log Model
struct CropLog: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var cropName: String
    var variety: String
    var fieldName: String
    var fieldSizeAcres: Double
    var soilType: SoilType
    var plantingDate: Date
    var expectedHarvestDate: Date
    var growthStage: GrowthStage
    var status: CropStatus
    var notes: String
    var photoURLs: [String]
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var updatedAt: Date

    var daysPlanted: Int {
        Calendar.current.dateComponents([.day], from: plantingDate, to: Date()).day ?? 0
    }

    var totalDays: Int {
        Calendar.current.dateComponents([.day], from: plantingDate, to: expectedHarvestDate).day ?? 90
    }

    var progressPercent: Double {
        guard totalDays > 0 else { return 0 }
        return min(Double(daysPlanted) / Double(totalDays), 1.0)
    }
}

enum SoilType: String, Codable, CaseIterable {
    case clayLoam = "Clay Loam"
    case sandyLoam = "Sandy Loam"
    case loam = "Loam"
    case clay = "Clay"
    case silt = "Silt"
    case peaty = "Peaty"
}

enum GrowthStage: String, Codable, CaseIterable {
    case germination = "Germination"
    case seedling = "Seedling"
    case tillering = "Tillering"
    case vegetative = "Vegetative"
    case flowering = "Flowering"
    case fruiting = "Fruiting"
    case maturity = "Maturity"
}

enum CropStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case growing = "Growing"
    case readyToHarvest = "Ready to Harvest"
    case harvested = "Harvested"
    case failed = "Failed"

    var color: String {
        switch self {
        case .planned: return "blue"
        case .growing: return "green"
        case .readyToHarvest: return "orange"
        case .harvested: return "gray"
        case .failed: return "red"
        }
    }
}

// MARK: - Disease Diagnosis Model
struct DiagnosisResult: Identifiable {
    var id = UUID()
    var diseaseName: String
    var confidence: Double
    var severity: DiseaseSeverity
    var description: String
    var remedies: [String]
    var preventionTips: [String]
    var imageURL: String?
    var timestamp: Date = Date()
}

enum DiseaseSeverity: String {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"

    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
}

// MARK: - Financial Model
struct FinancialTransaction: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var type: TransactionType
    var category: TransactionCategory
    var amount: Double
    var description: String
    var cropLogId: String?
    var date: Date
    var receiptURL: String?
    var createdAt: Date
}

enum TransactionType: String, Codable, CaseIterable {
    case income = "Income"
    case expense = "Expense"
}

enum TransactionCategory: String, Codable, CaseIterable {
    // Income
    case harvestSale = "Harvest Sale"
    case subsidyPayment = "Subsidy Payment"
    case otherIncome = "Other Income"
    // Expense
    case seeds = "Seeds"
    case fertilizer = "Fertilizer"
    case pesticide = "Pesticide"
    case labor = "Labor"
    case equipment = "Equipment"
    case irrigation = "Irrigation"
    case otherExpense = "Other Expense"

    var icon: String {
        switch self {
        case .harvestSale: return "💰"
        case .subsidyPayment: return "🏛"
        case .otherIncome: return "📈"
        case .seeds: return "🌱"
        case .fertilizer: return "🧪"
        case .pesticide: return "🐛"
        case .labor: return "👷"
        case .equipment: return "🚜"
        case .irrigation: return "💧"
        case .otherExpense: return "📤"
        }
    }
}

// MARK: - Service Location Model
struct AgriService: Identifiable, Codable {
    var id: String
    var name: String
    var type: ServiceType
    var address: String
    var district: String
    var latitude: Double
    var longitude: Double
    var phone: String?
    var openingHours: String?
    var isOpen: Bool?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum ServiceType: String, Codable, CaseIterable {
    case govijanaSeva = "Govijana Seva"
    case market = "Market"
    case supplier = "Supplier"
    case bank = "Agrarian Bank"

    var icon: String {
        switch self {
        case .govijanaSeva: return "building.columns"
        case .market: return "storefront"
        case .supplier: return "truck.box"
        case .bank: return "banknote"
        }
    }

    var markerColor: String {
        switch self {
        case .govijanaSeva: return "AgriGreen"
        case .market: return "orange"
        case .supplier: return "blue"
        case .bank: return "purple"
        }
    }
}

// MARK: - Alert / Notification Model
struct AgriAlert: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var type: AlertType
    var title: String
    var message: String
    var cropLogId: String?
    var isRead: Bool
    var scheduledDate: Date
    var createdAt: Date
}

enum AlertType: String, Codable {
    case watering = "Watering"
    case fertilizing = "Fertilizing"
    case disease = "Disease"
    case harvest = "Harvest"
    case general = "General"

    var icon: String {
        switch self {
        case .watering: return "drop.fill"
        case .fertilizing: return "leaf.fill"
        case .disease: return "cross.circle.fill"
        case .harvest: return "chart.bar.fill"
        case .general: return "bell.fill"
        }
    }

    var color: String {
        switch self {
        case .watering: return "blue"
        case .fertilizing: return "green"
        case .disease: return "red"
        case .harvest: return "orange"
        case .general: return "gray"
        }
    }
}

// MARK: - Calculator Model
struct CropInputRequirement {
    var cropName: String
    var landSizeAcres: Double
    var soilType: SoilType
    var seedsKg: Double
    var ureaKg: Double
    var tspKg: Double
    var muriatePotashKg: Double
    var waterLitersPerDay: Double
    var estimatedCostLKR: Double

    static func calculate(crop: CropType, acres: Double, soil: SoilType) -> CropInputRequirement {
        let base = crop.baseRequirements
        let soilMultiplier = soil.sandy ? 1.15 : 1.0
        return CropInputRequirement(
            cropName: crop.rawValue,
            landSizeAcres: acres,
            soilType: soil,
            seedsKg: base.seedsPerAcre * acres,
            ureaKg: base.ureaPerAcre * acres * soilMultiplier,
            tspKg: base.tspPerAcre * acres,
            muriatePotashKg: base.mkpPerAcre * acres,
            waterLitersPerDay: base.waterPerDay * acres,
            estimatedCostLKR: base.costPerAcre * acres
        )
    }
}

extension SoilType {
    var sandy: Bool { self == .sandyLoam }
}

enum CropType: String, CaseIterable {
    case paddy = "Paddy"
    case maize = "Maize"
    case chilli = "Red Chilli"
    case onion = "Big Onion"
    case tomato = "Tomato"
    case potato = "Potato"

    struct BaseRequirement {
        var seedsPerAcre: Double
        var ureaPerAcre: Double
        var tspPerAcre: Double
        var mkpPerAcre: Double
        var waterPerDay: Double
        var costPerAcre: Double
    }

    var baseRequirements: BaseRequirement {
        switch self {
        case .paddy:
            return BaseRequirement(seedsPerAcre: 10, ureaPerAcre: 30, tspPerAcre: 20, mkpPerAcre: 15, waterPerDay: 500, costPerAcre: 18000)
        case .maize:
            return BaseRequirement(seedsPerAcre: 8, ureaPerAcre: 35, tspPerAcre: 25, mkpPerAcre: 20, waterPerDay: 400, costPerAcre: 22000)
        case .chilli:
            return BaseRequirement(seedsPerAcre: 0.5, ureaPerAcre: 20, tspPerAcre: 15, mkpPerAcre: 12, waterPerDay: 350, costPerAcre: 35000)
        case .onion:
            return BaseRequirement(seedsPerAcre: 3, ureaPerAcre: 25, tspPerAcre: 18, mkpPerAcre: 14, waterPerDay: 300, costPerAcre: 40000)
        case .tomato:
            return BaseRequirement(seedsPerAcre: 0.3, ureaPerAcre: 28, tspPerAcre: 22, mkpPerAcre: 18, waterPerDay: 450, costPerAcre: 38000)
        case .potato:
            return BaseRequirement(seedsPerAcre: 400, ureaPerAcre: 40, tspPerAcre: 30, mkpPerAcre: 25, waterPerDay: 420, costPerAcre: 55000)
        }
    }

    var icon: String {
        switch self {
        case .paddy: return "🌾"
        case .maize: return "🌽"
        case .chilli: return "🌶"
        case .onion: return "🧅"
        case .tomato: return "🍅"
        case .potato: return "🥔"
        }
    }
}

// MARK: - Report Model
struct GrowthReport: Identifiable {
    var id = UUID()
    var user: AppUser
    var cropLog: CropLog
    var transactions: [FinancialTransaction]
    var generatedDate: Date = Date()

    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var netProfit: Double { totalIncome - totalExpenses }
}
