import Foundation

struct WeatherSnapshot: Codable, Equatable {
    let temperatureF: Double
    let feelsLikeF: Double?
    let conditionLabel: String
    let conditionSymbol: String
    let isDaylight: Bool
    let humidity: Double?
    let windMph: Double?
    let uvIndex: Int?
    let highF: Double?
    let lowF: Double?
    let placeName: String?
    let capturedAt: Date
    let hourly: [HourPoint]
    let daily: [DayPoint]

    struct HourPoint: Codable, Equatable {
        let date: Date
        let temperatureF: Double
        let conditionLabel: String
        let precipitationChance: Double  // 0...1
    }

    struct DayPoint: Codable, Equatable {
        let date: Date
        let highF: Double
        let lowF: Double
        let conditionLabel: String
        let precipitationChance: Double  // 0...1
    }

    var shortLine: String {
        let t = Int(temperatureF.rounded())
        if let high = highF, let low = lowF {
            return "\(conditionLabel), \(t)°F (H \(Int(high.rounded()))° / L \(Int(low.rounded()))°)"
        }
        return "\(conditionLabel), \(t)°F"
    }

    var contextLine: String {
        var parts: [String] = []
        let t = Int(temperatureF.rounded())
        parts.append("\(conditionLabel.lowercased()), \(t)°F")
        if let feels = feelsLikeF, abs(feels - temperatureF) >= 3 {
            parts.append("feels \(Int(feels.rounded()))°F")
        }
        if let high = highF, let low = lowF {
            parts.append("H \(Int(high.rounded()))° / L \(Int(low.rounded()))°")
        }
        if let humidity, humidity >= 0.7 {
            parts.append("humid \(Int(humidity * 100))%")
        }
        if let windMph, windMph >= 12 {
            parts.append("wind \(Int(windMph.rounded())) mph")
        }
        if let uvIndex, uvIndex >= 6 {
            parts.append("UV \(uvIndex)")
        }
        parts.append(isDaylight ? "daylight" : "after dark")
        if let place = placeName, !place.isEmpty {
            return "\(place) — \(parts.joined(separator: ", "))"
        }
        return parts.joined(separator: ", ")
    }

    /// Compact hourly outlook for the rest of today (sampled every 3h, max 5 points).
    var hourlyOutlook: String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? now
        let upcoming = hourly.filter { $0.date >= now && $0.date <= endOfDay }
        guard !upcoming.isEmpty else { return nil }

        var picked: [HourPoint] = []
        var lastTime: Date?
        for hp in upcoming {
            if let last = lastTime, hp.date.timeIntervalSince(last) < 3 * 3600 { continue }
            picked.append(hp)
            lastTime = hp.date
            if picked.count >= 5 { break }
        }
        guard !picked.isEmpty else { return nil }
        return picked.map { hp in
            let t = Int(hp.temperatureF.rounded())
            let pop = hp.precipitationChance >= 0.2 ? " \(Int(hp.precipitationChance * 100))%💧" : ""
            return "\(formatter.string(from: hp.date).lowercased()) \(hp.conditionLabel.lowercased()) \(t)°\(pop)"
        }.joined(separator: ", ")
    }

    /// Compact 5-day outlook starting tomorrow.
    var dailyOutlook: String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        let upcoming = daily.filter { $0.date >= tomorrow }.prefix(5)
        guard !upcoming.isEmpty else { return nil }
        return upcoming.map { dp in
            let high = Int(dp.highF.rounded())
            let low = Int(dp.lowF.rounded())
            let pop = dp.precipitationChance >= 0.2 ? " \(Int(dp.precipitationChance * 100))%💧" : ""
            return "\(formatter.string(from: dp.date)) \(dp.conditionLabel.lowercased()) \(high)°/\(low)°\(pop)"
        }.joined(separator: ", ")
    }
}
