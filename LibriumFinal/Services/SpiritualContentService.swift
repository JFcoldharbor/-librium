import Foundation

@MainActor
final class SpiritualContentService: ObservableObject {
    static let shared = SpiritualContentService()

    @Published private(set) var content: SpiritualContent = .empty
    @Published private(set) var isGenerating: Bool = false

    private let store: JSONStore
    private static let storageKey = "equilibrium.spiritual.content"
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private var inFlightTask: Task<Void, Never>?

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        content = store.load(SpiritualContent.self, key: Self.storageKey) ?? .empty
    }

    var motivationForToday: String? {
        guard let entry = content.dailyMotivation,
              entry.dateKey == Self.dayKey() else { return nil }
        return entry.text
    }

    var horoscopeDailyForToday: String? {
        guard let entry = content.horoscopeDaily,
              entry.dateKey == Self.dayKey() else { return nil }
        return entry.text
    }

    var horoscopeWeekly: String? {
        guard let entry = content.horoscopeWeekly,
              entry.weekKey == Self.weekKey() else { return nil }
        return entry.text
    }

    var horoscopeYearly: String? {
        guard let entry = content.horoscopeYearly,
              entry.yearKey == Self.yearKey() else { return nil }
        return entry.text
    }

    func saveDailyMotivation(_ text: String) {
        content.dailyMotivation = SpiritualContent.DailyEntry(
            text: text,
            dateKey: Self.dayKey(),
            generatedAt: Date()
        )
        persist()
    }

    func saveHoroscopeDaily(_ text: String) {
        content.horoscopeDaily = SpiritualContent.DailyEntry(
            text: text,
            dateKey: Self.dayKey(),
            generatedAt: Date()
        )
        persist()
    }

    func saveHoroscopeWeekly(_ text: String) {
        content.horoscopeWeekly = SpiritualContent.WeeklyEntry(
            text: text,
            weekKey: Self.weekKey(),
            generatedAt: Date()
        )
        persist()
    }

    func saveHoroscopeYearly(_ text: String) {
        content.horoscopeYearly = SpiritualContent.YearlyEntry(
            text: text,
            yearKey: Self.yearKey(),
            generatedAt: Date()
        )
        persist()
    }

    private func persist() {
        store.save(content, key: Self.storageKey)
    }

    static func dayKey(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }

    static func weekKey(now: Date = Date()) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return "\(year)-W\(week)"
    }

    static func yearKey(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: now)
    }

    // MARK: - Generation

    func refreshIfStale(zodiac: Zodiac?, now: Date = Date()) {
        guard inFlightTask == nil else { return }
        let needsDaily = motivationForToday == nil || (zodiac != nil && horoscopeDailyForToday == nil)
        let needsWeekly = zodiac != nil && horoscopeWeekly == nil
        let needsYearly = zodiac != nil && horoscopeYearly == nil

        guard needsDaily || needsWeekly || needsYearly else { return }
        guard !Secrets.openAIAPIKey.isEmpty else { return }

        let key = Secrets.openAIAPIKey
        let moon = MoonPhase.current(now: now)
        let dateString = Self.humanDate(now)
        let yearString = Self.yearKey(now: now)

        isGenerating = true
        inFlightTask = Task { [weak self] in
            if needsDaily {
                await self?.generateDaily(zodiac: zodiac, moon: moon, dateString: dateString, apiKey: key)
            }
            if needsWeekly, let zodiac = zodiac {
                await self?.generateWeekly(zodiac: zodiac, moon: moon, dateString: dateString, apiKey: key)
            }
            if needsYearly, let zodiac = zodiac {
                await self?.generateYearly(zodiac: zodiac, year: yearString, apiKey: key)
            }
            await MainActor.run {
                self?.isGenerating = false
                self?.inFlightTask = nil
            }
        }
    }

    private func generateDaily(zodiac: Zodiac?, moon: MoonPhase, dateString: String, apiKey: String) async {
        let signLine = zodiac.map { "Their zodiac: \($0.label) (\($0.element))." } ?? "They have no zodiac set yet."
        let horoscopeLine = zodiac == nil
            ? "Skip the horoscope — return horoscope_daily as an empty string."
            : "Daily horoscope: 2-3 sentences (~50 words). Speak to \(zodiac!.label)'s moment given the moon and date. Real psychological invitation, not 'love is in the air' fluff."

        let prompt = """
        Write a daily motivation and a daily horoscope for the user.

        Context:
        - \(signLine)
        - Today: \(dateString)
        - Moon phase: \(moon.kind.label) (\(Int(moon.illumination * 100))% illuminated)

        Tone: warm, direct, grounded. No emojis, no clichés, no preaching. Like a smart friend who knows them.

        Daily motivation: 1-2 sentences (~30 words). Earned and specific to the moment, not interchangeable.
        \(horoscopeLine)

        Return JSON: {"motivation": "...", "horoscope_daily": "..."}
        """

        struct Payload: Codable {
            let motivation: String
            let horoscope_daily: String
        }

        guard let payload: Payload = await Self.callOpenAI(prompt: prompt, apiKey: apiKey) else { return }
        await MainActor.run {
            if !payload.motivation.isEmpty {
                self.saveDailyMotivation(payload.motivation)
            }
            if zodiac != nil, !payload.horoscope_daily.isEmpty {
                self.saveHoroscopeDaily(payload.horoscope_daily)
            }
        }
    }

    private func generateWeekly(zodiac: Zodiac, moon: MoonPhase, dateString: String, apiKey: String) async {
        let prompt = """
        Write a weekly horoscope for a \(zodiac.label) (\(zodiac.element)).

        Week starting: \(dateString)
        Current moon: \(moon.kind.label)

        Tone: grounded, specific, ~80 words. No corny astrology jargon. One paragraph that names a real theme for the week.

        Return JSON: {"horoscope_weekly": "..."}
        """

        struct Payload: Codable {
            let horoscope_weekly: String
        }

        guard let payload: Payload = await Self.callOpenAI(prompt: prompt, apiKey: apiKey) else { return }
        await MainActor.run {
            if !payload.horoscope_weekly.isEmpty {
                self.saveHoroscopeWeekly(payload.horoscope_weekly)
            }
        }
    }

    private func generateYearly(zodiac: Zodiac, year: String, apiKey: String) async {
        let prompt = """
        Write a yearly outlook for a \(zodiac.label) (\(zodiac.element)).

        Year: \(year)

        Tone: grounded, thematic, ~120 words. Three movements: early year, mid year, late year. Specific themes — not "expansion awaits" fluff.

        Return JSON: {"horoscope_yearly": "..."}
        """

        struct Payload: Codable {
            let horoscope_yearly: String
        }

        guard let payload: Payload = await Self.callOpenAI(prompt: prompt, apiKey: apiKey) else { return }
        await MainActor.run {
            if !payload.horoscope_yearly.isEmpty {
                self.saveHoroscopeYearly(payload.horoscope_yearly)
            }
        }
    }

    private static func callOpenAI<T: Codable>(prompt: String, apiKey: String) async -> T? {
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 500,
            "temperature": 0.7,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "You return tight, grounded JSON-only responses for a personal-growth app. No clichés."],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }

        guard let outer = try? JSONDecoder().decode(SpiritualChatResponse.self, from: data),
              let content = outer.choices.first?.message.content,
              let payload = try? JSONDecoder().decode(T.self, from: Data(content.utf8)) else {
            return nil
        }
        return payload
    }

    private static func humanDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: date)
    }
}

private struct SpiritualChatResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let content: String }
}
