import Foundation
import UserNotifications

class NotificationManager {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[Notifications] Authorization error: \(error.localizedDescription)")
            } else {
                print("[Notifications] Authorization granted: \(granted)")
            }
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "CodePet misses you!"
        content.body = "Your pet is waiting to learn with you. Come back and practice!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Scheduling error: \(error.localizedDescription)")
            }
        }
    }
}
