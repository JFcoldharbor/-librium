import Foundation

@MainActor
final class BirthdayService: ObservableObject {
    static let shared = BirthdayService()

    @Published private(set) var birthday: Date?

    private static let key = "equilibrium.user.birthday"

    private init() {
        let timestamp = UserDefaults.standard.double(forKey: Self.key)
        if timestamp > 0 {
            birthday = Date(timeIntervalSince1970: timestamp)
        }
    }

    func set(_ date: Date) {
        birthday = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.key)
    }

    func clear() {
        birthday = nil
        UserDefaults.standard.removeObject(forKey: Self.key)
    }

    var zodiac: Zodiac? {
        birthday.map(Zodiac.from(date:))
    }
}
