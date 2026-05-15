import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class FirebaseAuthService {
    static let shared = FirebaseAuthService()
    private let db = Firestore.firestore(database: "agrismart-c2751")
    private init() {}

    var currentUser: FirebaseAuth.User? { Auth.auth().currentUser }

    // MARK: - Sign Up
    func signUp(email: String, password: String, userData: [String: Any]) async throws -> AppUser {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        var data = userData
        data["uid"] = result.user.uid
        data["createdAt"] = FieldValue.serverTimestamp()
        try await db.collection("users").document(result.user.uid).setData(data)
        return try await fetchUser(uid: result.user.uid)
    }

    // MARK: - Sign Up with mobile (uses email format internally)
    func signUpWithMobile(mobile: String, password: String, fullName: String,
                          district: String, farmName: String, farmSize: Double,
                          primaryCrop: String) async throws -> AppUser {
        let email = "\(mobile.replacingOccurrences(of: " ", with: ""))@agrismart.lk"
        let userData: [String: Any] = [
            "fullName": fullName,
            "mobile": mobile,
            "email": email,
            "district": district,
            "farmName": farmName,
            "farmSizeAcres": farmSize,
            "primaryCropType": primaryCrop
        ]
        return try await signUp(email: email, password: password, userData: userData)
    }

    // MARK: - Login
    func login(mobile: String, password: String) async throws -> AppUser {
        let email = "\(mobile.replacingOccurrences(of: " ", with: ""))@agrismart.lk"
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await fetchUser(uid: result.user.uid)
    }

    func loginWithEmail(email: String, password: String) async throws -> AppUser {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await fetchUser(uid: result.user.uid)
    }

    // MARK: - Logout
    func logout() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Password Reset
    func resetPassword(mobile: String) async throws {
        let email = "\(mobile.replacingOccurrences(of: " ", with: ""))@agrismart.lk"
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Fetch User
    func fetchUser(uid: String) async throws -> AppUser {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let user = try? doc.data(as: AppUser.self) else {
            throw NSError(domain: "AgriSmart", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        return user
    }

    // MARK: - Update User
    func updateUser(uid: String, data: [String: Any]) async throws {
        try await db.collection("users").document(uid).updateData(data)
    }

    // MARK: - Auth State Listener
    func authStatePublisher() -> AnyPublisher<FirebaseAuth.User?, Never> {
        let subject = PassthroughSubject<FirebaseAuth.User?, Never>()
        Auth.auth().addStateDidChangeListener { _, user in
            subject.send(user)
        }
        return subject.eraseToAnyPublisher()
    }
}
