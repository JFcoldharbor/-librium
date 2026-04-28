import MapKit
import SwiftUI

struct VenueSelection: Equatable {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
}

struct VenueSearchSheet: View {
    @Binding var selection: VenueSelection?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searcher = VenueSearcher()
    @ObservedObject private var meetingService = MeetingCaptureService.shared

    @State private var query: String = ""
    @State private var resolving: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    if resolving {
                        loadingState
                    } else {
                        resultList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Location")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .onAppear {
                meetingService.requestPermissionIfNeeded()
            }
            .onChange(of: query) { _, newValue in
                searcher.update(query: newValue)
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.20),
                    EquilibriumColor.CardTint.network.opacity(0.04),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.tertiaryText)
            TextField("Search address, venue, or place", text: $query)
                .foregroundColor(EquilibriumColor.primaryText)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.06))
        )
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                useMyLocationRow

                if !searcher.results.isEmpty {
                    Text("MATCHES")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.5)
                        .foregroundColor(EquilibriumColor.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.leading, 4)

                    ForEach(searcher.results, id: \.self) { result in
                        Button {
                            Task { await selectCompletion(result) }
                        } label: {
                            completionRow(result)
                        }
                        .buttonStyle(.plain)
                    }
                } else if !query.isEmpty {
                    Text("No matches yet — keep typing.")
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    private var useMyLocationRow: some View {
        Button {
            Task { await selectCurrentLocation() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EquilibriumColor.CardTint.network)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(EquilibriumColor.CardTint.network.opacity(0.18)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use my current location")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                    Text("Hosts where you are right now")
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(EquilibriumColor.primaryText.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func completionRow(_ completion: MKLocalSearchCompletion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.CardTint.network)
                .frame(width: 32, height: 32)
                .background(Circle().fill(EquilibriumColor.CardTint.network.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineLimit(1)
                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.03))
        )
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 60)
            ProgressView().tint(EquilibriumColor.CardTint.network)
            Text("Looking up location…")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        resolving = true
        defer { resolving = false }
        if let result = await searcher.resolve(completion) {
            selection = result
            dismiss()
        }
    }

    private func selectCurrentLocation() async {
        resolving = true
        defer { resolving = false }
        let context = await meetingService.captureContext()
        guard context.hasCoordinates,
              let lat = context.latitude,
              let lng = context.longitude else { return }
        let name = context.placeName ?? "Current location"
        selection = VenueSelection(
            name: name,
            address: context.placeName ?? String(format: "%.4f, %.4f", lat, lng),
            latitude: lat,
            longitude: lng
        )
        dismiss()
    }
}

@MainActor
final class VenueSearcher: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            completer.cancel()
            return
        }
        completer.queryFragment = trimmed
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> VenueSelection? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let placemark = item.placemark
            let parts: [String?] = [
                placemark.subThoroughfare,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea
            ]
            let address = parts.compactMap { $0 }.joined(separator: ", ")
            return VenueSelection(
                name: item.name ?? completion.title,
                address: address.isEmpty ? completion.subtitle : address,
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude
            )
        } catch {
            return nil
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let snapshot = completer.results
        Task { @MainActor in
            self.results = snapshot
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
        }
    }
}
