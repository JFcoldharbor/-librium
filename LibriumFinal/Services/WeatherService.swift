import CoreLocation
import Foundation
import WeatherKit

@MainActor
final class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()

    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var lastError: String?

    private let weatherService = WeatherKit.WeatherService.shared
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    private static let cacheTTL: TimeInterval = 30 * 60 // 30 minutes
    private var lastFetchAt: Date?
    private var inFlight: Task<WeatherSnapshot?, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Returns a fresh snapshot or the cached one if still within TTL.
    func current(now: Date = Date()) async -> WeatherSnapshot? {
        if let cached = snapshot, let last = lastFetchAt, now.timeIntervalSince(last) < Self.cacheTTL {
            return cached
        }
        if let inFlight {
            return await inFlight.value
        }
        let task = Task<WeatherSnapshot?, Never> { [weak self] in
            await self?.fetch(now: now)
        }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    /// Force a refresh, ignoring cache. Safe to call from a Combine timer or app foreground.
    @discardableResult
    func refresh(now: Date = Date()) async -> WeatherSnapshot? {
        lastFetchAt = nil
        return await current(now: now)
    }

    private func fetch(now: Date) async -> WeatherSnapshot? {
        guard let location = await currentLocation() else {
            lastError = "Location unavailable"
            return snapshot
        }
        do {
            let weather = try await weatherService.weather(for: location)
            let place = await reverseGeocode(location)
            let new = Self.snapshot(from: weather, place: place, now: now)
            snapshot = new
            lastFetchAt = now
            lastError = nil
            return new
        } catch {
            lastError = error.localizedDescription
            return snapshot
        }
    }

    private static func snapshot(from weather: Weather, place: String?, now: Date) -> WeatherSnapshot {
        let current = weather.currentWeather
        let today = weather.dailyForecast.first

        let tempF = current.temperature.converted(to: .fahrenheit).value
        let feelsF = current.apparentTemperature.converted(to: .fahrenheit).value
        let highF = today?.highTemperature.converted(to: .fahrenheit).value
        let lowF = today?.lowTemperature.converted(to: .fahrenheit).value
        let windMph = current.wind.speed.converted(to: .milesPerHour).value

        let endOfTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: now)) ?? now
        let hourly = weather.hourlyForecast
            .filter { $0.date >= now && $0.date < endOfTomorrow }
            .prefix(24)
            .map { hour in
                WeatherSnapshot.HourPoint(
                    date: hour.date,
                    temperatureF: hour.temperature.converted(to: .fahrenheit).value,
                    conditionLabel: hour.condition.description,
                    precipitationChance: hour.precipitationChance
                )
            }

        let daily = weather.dailyForecast
            .prefix(7)
            .map { day in
                WeatherSnapshot.DayPoint(
                    date: day.date,
                    highF: day.highTemperature.converted(to: .fahrenheit).value,
                    lowF: day.lowTemperature.converted(to: .fahrenheit).value,
                    conditionLabel: day.condition.description,
                    precipitationChance: day.precipitationChance
                )
            }

        return WeatherSnapshot(
            temperatureF: tempF,
            feelsLikeF: abs(feelsF - tempF) >= 1 ? feelsF : nil,
            conditionLabel: current.condition.description,
            conditionSymbol: current.symbolName,
            isDaylight: current.isDaylight,
            humidity: current.humidity,
            windMph: windMph >= 1 ? windMph : nil,
            uvIndex: current.uvIndex.value,
            highF: highF,
            lowF: lowF,
            placeName: place,
            capturedAt: now,
            hourly: Array(hourly),
            daily: Array(daily)
        )
    }

    // MARK: - Location

    private func currentLocation() async -> CLLocation? {
        #if os(macOS)
        return nil
        #else
        let auth = await resolvedAuthStatus()
        guard auth == .authorizedWhenInUse || auth == .authorizedAlways else { return nil }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
        #endif
    }

    private func resolvedAuthStatus() async -> CLAuthorizationStatus {
        let current = locationManager.authorizationStatus
        if current != .notDetermined { return current }
        locationManager.requestWhenInUseAuthorization()
        return await withCheckedContinuation { continuation in
            authContinuation = continuation
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                let place = placemarks?.first
                let name = place?.locality ?? place?.subLocality ?? place?.name
                continuation.resume(returning: name)
            }
        }
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            if status != .notDetermined {
                self.authContinuation?.resume(returning: status)
                self.authContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let first = locations.first
        Task { @MainActor in
            self.locationContinuation?.resume(returning: first)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }
}
