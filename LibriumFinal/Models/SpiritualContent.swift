import Foundation

struct SpiritualContent: Codable, Equatable {
    var dailyMotivation: DailyEntry?
    var horoscopeDaily: DailyEntry?
    var horoscopeWeekly: WeeklyEntry?
    var horoscopeYearly: YearlyEntry?

    struct DailyEntry: Codable, Equatable {
        let text: String
        let dateKey: String
        let generatedAt: Date
    }

    struct WeeklyEntry: Codable, Equatable {
        let text: String
        let weekKey: String
        let generatedAt: Date
    }

    struct YearlyEntry: Codable, Equatable {
        let text: String
        let yearKey: String
        let generatedAt: Date
    }

    static let empty = SpiritualContent()
}
