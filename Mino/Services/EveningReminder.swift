import Foundation
import UserNotifications

/// The only notification Mino sends: the evening ritual, opt-in, for the next three evenings.
/// If the app is not opened for three days, Mino falls silent rather than insisting.
@MainActor
enum EveningReminder {
    private static let identifierPrefix = "mino.evening."
    private static let horizon = 3

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// `message(day)` writes the text announcing `day`'s outfits.
    static func schedule(minutesAfterMidnight: Int, calendar: Calendar, message: (Date) -> String) async {
        let center = UNUserNotificationCenter.current()
        cancel()
        let now = Date.now
        var evening = calendar.date(
            bySettingHour: minutesAfterMidnight / 60, minute: minutesAfterMidnight % 60, second: 0, of: now
        ) ?? now
        if evening <= now { evening = calendar.date(byAdding: .day, value: 1, to: evening) ?? evening }

        for index in 0..<horizon {
            guard let fireDate = calendar.date(byAdding: .day, value: index, to: evening),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: fireDate) else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Demain, c'est prêt"
            content.body = message(nextDay)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + String(index),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: (0..<horizon).map { identifierPrefix + String($0) }
        )
    }
}
