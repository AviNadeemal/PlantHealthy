import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    @Published var isAuthorized = false

    override private init() {
        super.init()
    }

    // MARK: - Request Permission
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { self.isAuthorized = granted }
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    // MARK: - Schedule Crop Alert
    func scheduleCropAlert(cropLog: CropLog, type: AlertType, daysFromNow: Int) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.badge = 1

        switch type {
        case .watering:
            content.title = "💧 Watering Reminder"
            content.body = "\(cropLog.cropName) in \(cropLog.fieldName) needs watering today."
            content.categoryIdentifier = "WATERING"
        case .fertilizing:
            content.title = "🌿 Fertilizing Time"
            content.body = "Time to fertilize \(cropLog.cropName) in \(cropLog.fieldName)."
            content.categoryIdentifier = "FERTILIZING"
        case .harvest:
            content.title = "🌾 Harvest Alert"
            content.body = "\(cropLog.cropName) in \(cropLog.fieldName) is approaching harvest!"
            content.categoryIdentifier = "HARVEST"
        default:
            content.title = "🌱 AgriSmart Alert"
            content.body = "Check your \(cropLog.cropName) crop."
        }

        content.userInfo = ["cropLogId": cropLog.id ?? "", "alertType": type.rawValue]

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day],
                                                             from: Date().addingTimeInterval(TimeInterval(daysFromNow * 86400)))
        dateComponents.hour = 6
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let identifier = "agrismart_\(cropLog.id ?? UUID().uuidString)_\(type.rawValue)_\(daysFromNow)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Schedule Automated Cycle Alerts for a Crop
    func scheduleGrowthCycleAlerts(for cropLog: CropLog) {
        cancelAlerts(for: cropLog)

        // Watering every 3 days for the first 30 days
        for day in stride(from: 3, through: 30, by: 3) {
            scheduleCropAlert(cropLog: cropLog, type: .watering, daysFromNow: day)
        }

        // Fertilizing at week 2, 4, 6
        for week in [14, 28, 42] {
            scheduleCropAlert(cropLog: cropLog, type: .fertilizing, daysFromNow: week)
        }

        // Harvest warning 7 days before expected harvest
        let daysToHarvest = cropLog.totalDays - 7
        if daysToHarvest > 0 {
            scheduleCropAlert(cropLog: cropLog, type: .harvest, daysFromNow: daysToHarvest)
        }
    }

    // MARK: - Cancel Alerts for a Crop
    func cancelAlerts(for cropLog: CropLog) {
        guard let id = cropLog.id else { return }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.identifier.contains(id) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: - Cancel All
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Get Pending Count
    func getPendingCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests.count)
        }
    }

    // MARK: - FCM Token
    func getFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, _ in completion(token) }
    }
}
