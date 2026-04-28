import SwiftUI

struct LifeSpiritualCard: View {
    @ObservedObject var viewModel: LifeHubViewModel
    @ObservedObject private var birthdayService = BirthdayService.shared
    @ObservedObject private var contentService = SpiritualContentService.shared

    @State private var showBirthdayCapture = false
    @State private var showBreathing = false
    @State private var horoscopeRange: HoroscopeRange = .daily
    @State private var nowTick: Date = Date()

    private let tickTimer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()

    enum HoroscopeRange: String, CaseIterable, Identifiable {
        case daily, weekly, yearly
        var id: String { rawValue }
        var label: String {
            switch self {
            case .daily: return "Today"
            case .weekly: return "Week"
            case .yearly: return "Year"
            }
        }
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 80)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 16) {
                        moonHero

                        motivationBlock

                        horoscopeBlock

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Floating breathing pill
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    breathingPill
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .onReceive(tickTimer) { nowTick = $0 }
        .task {
            contentService.refreshIfStale(zodiac: birthdayService.zodiac)
        }
        .onChange(of: birthdayService.birthday) { _, _ in
            contentService.refreshIfStale(zodiac: birthdayService.zodiac)
        }
        .sheet(isPresented: $showBirthdayCapture) {
            BirthdayCaptureSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBreathing) {
            BreathingSheet(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.spiritual.opacity(0.32),
                    EquilibriumColor.CardTint.spiritual.opacity(0.08),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 60,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SPIRITUAL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(EquilibriumColor.CardTint.spiritual)
                Spacer()
                if let zodiac = birthdayService.zodiac {
                    HStack(spacing: 4) {
                        Text(zodiac.glyph)
                        Text(zodiac.label)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(EquilibriumColor.CardTint.spiritual)
                }
            }
            Text(MoonPhase.current(now: nowTick).kind.label)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    // MARK: - Moon hero

    private var moonHero: some View {
        let phase = MoonPhase.current(now: nowTick)
        return VStack(spacing: 12) {
            MoonGlyph(phase: phase.phase, illumination: phase.illumination, size: 160)
                .frame(width: 160, height: 160)
            Text("\(Int(phase.illumination * 100))% illuminated")
                .font(.system(size: 11))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Motivation

    private var motivationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("DAILY MOTIVATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                Spacer()
                if contentService.isGenerating && contentService.motivationForToday == nil {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(EquilibriumColor.CardTint.spiritual)
                }
            }
            .foregroundColor(EquilibriumColor.CardTint.spiritual)

            Text(motivationText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(motivationForeground)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(EquilibriumColor.CardTint.spiritual.opacity(0.18), lineWidth: 0.5)
                )
        )
    }

    private var motivationText: String {
        if let saved = contentService.motivationForToday {
            return saved
        }
        if contentService.isGenerating {
            return "Maria's reading the day…"
        }
        return "Maria's motivation will land here when she opens the chart."
    }

    private var motivationForeground: Color {
        contentService.motivationForToday == nil ? EquilibriumColor.secondaryText : EquilibriumColor.primaryText
    }

    // MARK: - Horoscope

    private var horoscopeBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("HOROSCOPE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                Spacer()
                if contentService.isGenerating && horoscopeForCurrentRange == nil && birthdayService.birthday != nil {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(EquilibriumColor.CardTint.spiritual)
                }
                if birthdayService.birthday == nil {
                    Button {
                        showBirthdayCapture = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                            Text("Set birthday")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(EquilibriumColor.CardTint.spiritual)
                    }
                } else {
                    Button {
                        showBirthdayCapture = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 14))
                            .foregroundColor(EquilibriumColor.CardTint.spiritual.opacity(0.7))
                    }
                }
            }
            .foregroundColor(EquilibriumColor.CardTint.spiritual)

            if birthdayService.birthday != nil {
                rangePicker
                Text(horoscopeText)
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Add your birthday so Maria can read your sky.")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(EquilibriumColor.CardTint.spiritual.opacity(0.18), lineWidth: 0.5)
                )
        )
    }

    private var rangePicker: some View {
        HStack(spacing: 6) {
            ForEach(HoroscopeRange.allCases) { range in
                rangeChip(range)
            }
        }
    }

    private func rangeChip(_ range: HoroscopeRange) -> some View {
        let isSelected = horoscopeRange == range
        return Button {
            horoscopeRange = range
        } label: {
            Text(range.label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected
                        ? EquilibriumColor.CardTint.spiritual.opacity(0.25)
                        : EquilibriumColor.primaryText.opacity(0.05))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? EquilibriumColor.CardTint.spiritual.opacity(0.55) : Color.clear,
                        lineWidth: 1
                    )
                )
                .foregroundColor(isSelected ? EquilibriumColor.CardTint.spiritual : EquilibriumColor.secondaryText)
        }
    }

    private var horoscopeText: String {
        if let cached = horoscopeForCurrentRange { return cached }
        if contentService.isGenerating {
            switch horoscopeRange {
            case .daily: return "Maria's tracing today's chart…"
            case .weekly: return "Maria's mapping the week…"
            case .yearly: return "Maria's sweeping the year…"
            }
        }
        return "Tap a range — Maria will write it on next open."
    }

    private var horoscopeForCurrentRange: String? {
        switch horoscopeRange {
        case .daily: return contentService.horoscopeDailyForToday
        case .weekly: return contentService.horoscopeWeekly
        case .yearly: return contentService.horoscopeYearly
        }
    }

    // MARK: - Breathing pill

    private var breathingPill: some View {
        Button(action: { showBreathing = true }) {
            ZStack {
                Circle()
                    .fill(EquilibriumColor.CardTint.spiritual)
                    .frame(width: 56, height: 56)
                    .shadow(color: EquilibriumColor.CardTint.spiritual.opacity(0.45), radius: 16, y: 4)
                Image(systemName: "wind")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Moon glyph

private struct MoonGlyph: View {
    let phase: Double          // 0...1
    let illumination: Double   // 0...1
    let size: CGFloat

    var body: some View {
        ZStack {
            // Halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            EquilibriumColor.CardTint.spiritual.opacity(0.40),
                            EquilibriumColor.CardTint.spiritual.opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.35,
                        endRadius: size * 0.75
                    )
                )

            // Dark moon disc
            Circle()
                .fill(Color(white: 0.05))
                .frame(width: size * 0.78, height: size * 0.78)
                .overlay(
                    Circle()
                        .stroke(EquilibriumColor.CardTint.spiritual.opacity(0.35), lineWidth: 1)
                )

            // Lit portion
            MoonLitShape(phase: phase)
                .fill(LinearGradient(
                    colors: [Color(white: 0.95), Color(white: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size * 0.78, height: size * 0.78)
                .clipShape(Circle())

            // Subtle shadow line at terminator
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .frame(width: size * 0.78, height: size * 0.78)
        }
    }
}

private struct MoonLitShape: Shape {
    let phase: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // 0 = new (none lit), 0.5 = full (all lit), 1 = new
        // Waxing: phase 0 → 0.5, lit grows from right
        // Waning: phase 0.5 → 1, lit shrinks toward left

        if phase < 0.02 || phase > 0.98 {
            return Path() // new moon
        }

        var path = Path()

        if phase < 0.5 {
            // waxing: right semicircle outline
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
            // terminator ellipse: width shrinks to zero at full
            // At phase=0: terminator at right edge (full ellipse on right) → no light
            // At phase=0.25: terminator vertical → half lit
            // At phase=0.5: terminator at left edge → full
            let widthFactor = cos(phase * 2 * .pi) // 1 at new, 0 at half, -1 at full
            let ellipseRadius = abs(widthFactor) * radius
            if widthFactor > 0 {
                // ellipse on right side carves out unlit
                path.addEllipse(in: CGRect(
                    x: center.x - ellipseRadius,
                    y: center.y - radius,
                    width: ellipseRadius * 2,
                    height: radius * 2
                ).standardized)
            } else {
                // ellipse on right adds to lit
                path.addEllipse(in: CGRect(
                    x: center.x - ellipseRadius,
                    y: center.y - radius,
                    width: ellipseRadius * 2,
                    height: radius * 2
                ))
            }
        } else {
            // waning: left semicircle outline
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(-90),
                clockwise: false
            )
            let widthFactor = cos(phase * 2 * .pi) // -1 at full, 0 at half, 1 at new
            let ellipseRadius = abs(widthFactor) * radius
            if widthFactor > 0 {
                path.addEllipse(in: CGRect(
                    x: center.x - ellipseRadius,
                    y: center.y - radius,
                    width: ellipseRadius * 2,
                    height: radius * 2
                ))
            } else {
                path.addEllipse(in: CGRect(
                    x: center.x - ellipseRadius,
                    y: center.y - radius,
                    width: ellipseRadius * 2,
                    height: radius * 2
                ))
            }
        }

        return path
    }
}
