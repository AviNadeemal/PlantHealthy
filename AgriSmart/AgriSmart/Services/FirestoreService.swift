import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore(database: "agrismart-c2751")
    private let storage = Storage.storage()
    private init() {}

    // MARK: - Crop Logs
    func saveCropLog(_ cropLog: CropLog) async throws -> String {
        var data = try Firestore.Encoder().encode(cropLog)
        data["updatedAt"] = FieldValue.serverTimestamp()
        if let id = cropLog.id {
            try await db.collection("cropLogs").document(id).setData(data, merge: true)
            return id
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
            let ref = try await db.collection("cropLogs").addDocument(data: data)
            return ref.documentID
        }
    }

    func fetchCropLogs(userId: String) async throws -> [CropLog] {
        let snapshot = try await db.collection("cropLogs")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CropLog.self) }
    }

    func deleteCropLog(id: String) async throws {
        try await db.collection("cropLogs").document(id).delete()
    }

    func listenToCropLogs(userId: String, completion: @escaping ([CropLog]) -> Void) -> ListenerRegistration {
        return db.collection("cropLogs")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let logs = snapshot?.documents.compactMap { try? $0.data(as: CropLog.self) } ?? []
                completion(logs)
            }
    }

    // MARK: - Financial Transactions
    func saveTransaction(_ transaction: FinancialTransaction) async throws -> String {
        var data = try Firestore.Encoder().encode(transaction)
        if let id = transaction.id {
            try await db.collection("transactions").document(id).setData(data, merge: true)
            return id
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
            let ref = try await db.collection("transactions").addDocument(data: data)
            return ref.documentID
        }
    }

    func fetchTransactions(userId: String) async throws -> [FinancialTransaction] {
        let snapshot = try await db.collection("transactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FinancialTransaction.self) }
    }

    func deleteTransaction(id: String) async throws {
        try await db.collection("transactions").document(id).delete()
    }

    func listenToTransactions(userId: String, completion: @escaping ([FinancialTransaction]) -> Void) -> ListenerRegistration {
        return db.collection("transactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, _ in
                let txns = snapshot?.documents.compactMap { try? $0.data(as: FinancialTransaction.self) } ?? []
                completion(txns)
            }
    }

    // MARK: - Alerts
    func saveAlert(_ alert: AgriAlert) async throws {
        var data = try Firestore.Encoder().encode(alert)
        if let id = alert.id {
            try await db.collection("alerts").document(id).setData(data, merge: true)
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
            try await db.collection("alerts").addDocument(data: data)
        }
    }

    func fetchAlerts(userId: String) async throws -> [AgriAlert] {
        let snapshot = try await db.collection("alerts")
            .whereField("userId", isEqualTo: userId)
            .order(by: "scheduledDate", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: AgriAlert.self) }
    }

    func markAlertRead(id: String) async throws {
        try await db.collection("alerts").document(id).updateData(["isRead": true])
    }

    func listenToAlerts(userId: String, completion: @escaping ([AgriAlert]) -> Void) -> ListenerRegistration {
        return db.collection("alerts")
            .whereField("userId", isEqualTo: userId)
            .order(by: "scheduledDate", descending: true)
            .addSnapshotListener { snapshot, _ in
                let alerts = snapshot?.documents.compactMap { try? $0.data(as: AgriAlert.self) } ?? []
                completion(alerts)
            }
    }

    // MARK: - Service Locations (static data seeded to Firestore)
    func fetchAgriServices(district: String? = nil) async throws -> [AgriService] {
        var query: Query = db.collection("agriServices")
        if let district = district {
            query = query.whereField("district", isEqualTo: district)
        }
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: AgriService.self) }
    }

    // MARK: - Photo Upload
    func uploadImage(data: Data, path: String) async throws -> String {
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func uploadCropPhoto(userId: String, cropLogId: String, imageData: Data) async throws -> String {
        let path = "cropPhotos/\(userId)/\(cropLogId)/\(UUID().uuidString).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    func uploadDiagnosisPhoto(userId: String, imageData: Data) async throws -> String {
        let path = "diagnosisPhotos/\(userId)/\(UUID().uuidString).jpg"
        return try await uploadImage(data: imageData, path: path)
    }

    // MARK: - Diagnosis History
    func saveDiagnosis(userId: String, result: DiagnosisResult, imageURL: String?) async throws {
        var data: [String: Any] = [
            "userId": userId,
            "diseaseName": result.diseaseName,
            "confidence": result.confidence,
            "severity": result.severity.rawValue,
            "description": result.description,
            "remedies": result.remedies,
            "timestamp": FieldValue.serverTimestamp()
        ]
        if let url = imageURL { data["imageURL"] = url }
        try await db.collection("diagnosisHistory").addDocument(data: data)
    }
}
