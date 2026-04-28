import Foundation
import UserNotifications
#if !os(macOS)
import UIKit
#endif

/// Singleton delegate that handles incoming notification taps and action buttons.
/// Specifically: turns a "Directions" tap on a meeting heads-up into an Apple Maps deep link.
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()

    static let meetingCategoryID = "MEETING_HEADSUP"
    static let directionsActionID = "GET_DIRECTIONS"
    static let venueUserInfoKey = "venue"

    private override init() { super.init() }

    /// Allow notifications to display while the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case Self.directionsActionID:
            if let venue = userInfo[Self.venueUserInfoKey] as? String, !venue.isEmpty {
                openMaps(for: venue)
            }
        default:
            break
        }
    }

    private func openMaps(for venue: String) {
        #if !os(macOS)
        guard let encoded = venue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)&dirflg=d") else {
            return
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
