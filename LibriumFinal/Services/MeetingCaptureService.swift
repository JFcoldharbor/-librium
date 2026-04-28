import CoreLocation
import Foundation

@MainActor
final class MeetingCaptureService: NSObject, ObservableObject {
    static let shared = MeetingCaptureService()

    @Published private(set) var status: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }

    func requestPermissionIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func captureContext(now: Date = Date()) async -> MeetingContext {
        async let event = nearestEventTitle(now: now)
        async let locationData = currentLocationAndPlace()

        let location = await locationData
        return MeetingContext(
            latitude: location.coordinate?.latitude,
            longitude: location.coordinate?.longitude,
            placeName: location.placeName,
            eventTitle: await event,
            capturedAt: now
        )
    }

    // MARK: - Location

    private func currentLocationAndPlace() async -> (coordinate: CLLocationCoordinate2D?, placeName: String?) {
        guard let location = await currentLocation() else {
            return (nil, nil)
        }
        let place = await reverseGeocode(location)
        return (location.coordinate, place)
    }

    private func currentLocation() async -> CLLocation? {
        #if os(macOS)
        return nil
        #else
        let auth = await resolvedAuthStatus()
        guard auth == .authorizedWhenInUse || auth == .authorizedAlways else { return nil }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
        #endif
    }

    private func resolvedAuthStatus() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined { return current }
        manager.requestWhenInUseAuthorization()
        return await withCheckedContinuation { continuation in
            authContinuation = continuation
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        return await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let candidates: [String] = [
                    placemark.name,
                    placemark.subLocality,
                    placemark.locality
                ].compactMap { $0 }.filter { !$0.isEmpty }

                var seen: Set<String> = []
                var unique: [String] = []
                for value in candidates where !seen.contains(value) {
                    seen.insert(value)
                    unique.append(value)
                }
                let result = unique.prefix(2).joined(separator: ", ")
                continuation.resume(returning: result.isEmpty ? nil : result)
            }
        }
    }

    // MARK: - Nearest event

    private func nearestEventTitle(now: Date) async -> String? {
        guard CalendarService.shared.accessState == .authorized else { return nil }
        let snapshot = await CalendarService.shared.loadTodaysSnapshot(now: now)
        let timed: [CalendarEventSummary] = snapshot.allEventsToday.filter { !$0.isAllDay }
        guard !timed.isEmpty else { return nil }

        if let live = timed.first(where: { $0.startDate <= now && now < $0.endDate }) {
            return live.title
        }

        let pastTwoHours = now.addingTimeInterval(-2 * 3600)
        let nextTwoHours = now.addingTimeInterval(2 * 3600)
        let candidates: [CalendarEventSummary] = timed.filter { event in
            event.startDate >= pastTwoHours && event.startDate <= nextTwoHours
        }
        var best: CalendarEventSummary?
        var bestDistance: TimeInterval = .greatestFiniteMagnitude
        for event in candidates {
            let distance = abs(event.startDate.timeIntervalSince(now))
            if distance < bestDistance {
                best = event
                bestDistance = distance
            }
        }
        return best?.title
    }
}

extension MeetingCaptureService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.status = status
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

struct MeetingContext: Equatable {
    let latitude: Double?
    let longitude: Double?
    let placeName: String?
    let eventTitle: String?
    let capturedAt: Date

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var noteLine: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        var parts: [String] = ["Met \(dateFormatter.string(from: capturedAt))"]
        if let place = placeName, !place.isEmpty {
            parts.append("at \(place)")
        }
        if let event = eventTitle, !event.isEmpty {
            parts.append("· Event: \(event)")
        }
        return parts.joined(separator: " ")
    }
}
