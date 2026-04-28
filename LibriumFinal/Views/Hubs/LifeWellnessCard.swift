import SwiftUI

struct LifeWellnessCard: View {
    @ObservedObject var viewModel: LifeHubViewModel

    @State private var showHistory = false
    @State private var showBreathing = false
    @State private var showHealthDetail = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 80)
                    .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 16) {
                        ringHero

                        statStrip

                        waterSection

                        sleepSection

                        energySection

                        Spacer().frame(height: 110)
                    }
                    .padding(.horizontal, 20)
                }
            }

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
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 16) {
                Button(action: { showHealthDetail = true }) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 16))
                        .foregroundColor(EquilibriumColor.CardTint.health.opacity(0.8))
                }
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(EquilibriumColor.CardTint.health.opacity(0.8))
                }
            }
            .padding(.top, 80)
            .padding(.trailing, 24)
        }
        .sheet(isPresented: $showHistory) {
            WellnessHistoryView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBreathing) {
            BreathingSheet(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showHealthDetail) {
            HealthDetailView()
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.health.opacity(0.30),
                    EquilibriumColor.CardTint.health.opacity(0.07),
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
                Text("HEALTH")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(EquilibriumColor.CardTint.health)
                Spacer()
                if viewModel.healthAccess != .authorized {
                    Text("Apple Health off")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }
            Text(headlineCopy)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var headlineCopy: String {
        let h = viewModel.healthSnapshot
        if viewModel.healthAccess != .authorized { return "Vitals" }
        if h.sleepHours > 0 && h.sleepHours < 6 { return "Sleep was short" }
        if h.stepCount > 8000 { return "Moving well" }
        if h.mindfulMinutes > 0 { return "You showed up" }
        return "Today's body"
    }

    // MARK: - Ring hero

    private var ringHero: some View {
        let h = viewModel.healthSnapshot
        let move = min(1.0, Double(h.activeKcal) / 500.0)
        let steps = min(1.0, Double(h.stepCount) / 10_000.0)
        let mindful = min(1.0, Double(h.mindfulMinutes) / 10.0)

        return VStack(spacing: 12) {
            ZStack {
                ringArc(progress: move, color: EquilibriumColor.CardTint.health, scale: 1.0)
                ringArc(progress: steps, color: Color.cyan, scale: 0.78)
                ringArc(progress: mindful, color: Color(red: 0.62, green: 0.45, blue: 0.92), scale: 0.56)

                VStack(spacing: 0) {
                    Text("\(h.stepCount)")
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.primaryText)
                    Text("steps")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
            }
            .frame(width: 200, height: 200)

            HStack(spacing: 16) {
                ringLegend(color: EquilibriumColor.CardTint.health, label: "MOVE", value: "\(h.activeKcal)/500 kcal")
                ringLegend(color: Color.cyan, label: "STEPS", value: "\(h.stepCount)/10k")
                ringLegend(color: Color(red: 0.62, green: 0.45, blue: 0.92), label: "MIND", value: "\(h.mindfulMinutes)/10m")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
    }

    private func ringArc(progress: Double, color: Color, scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .scaleEffect(scale)
    }

    private func ringLegend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Text(value)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
            }
        }
    }

    // MARK: - Stat strip (sleep, water, HR)

    private var statStrip: some View {
        let h = viewModel.healthSnapshot
        return HStack(spacing: 10) {
            statTile(
                icon: "bed.double.fill",
                label: "SLEEP",
                value: h.sleepHours > 0 ? String(format: "%.1fh", h.sleepHours) : "—"
            )
            statTile(
                icon: "drop.fill",
                label: "WATER",
                value: waterLabel
            )
            statTile(
                icon: "heart.fill",
                label: "RESTING",
                value: h.restingHeartRate > 0 ? "\(h.restingHeartRate)" : "—",
                suffix: h.restingHeartRate > 0 ? "bpm" : nil
            )
        }
    }

    private var waterLabel: String {
        let h = viewModel.healthSnapshot
        if h.waterOunces > 0 {
            return "\(Int(h.waterOunces))oz"
        }
        return "\(viewModel.todayWellness.waterGlasses * 16)oz"
    }

    private func statTile(icon: String, label: String, value: String, suffix: String? = nil) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.CardTint.health)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 10))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(EquilibriumColor.CardTint.health.opacity(0.12), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Water section

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("WATER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                Spacer()
                Text("\(displayedGlasses) / 8 glasses · 16oz each")
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            .foregroundColor(EquilibriumColor.CardTint.health)

            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { idx in
                    Image(systemName: idx < displayedGlasses ? "drop.fill" : "drop")
                        .font(.system(size: 22))
                        .foregroundColor(
                            idx < displayedGlasses
                                ? EquilibriumColor.CardTint.health
                                : EquilibriumColor.CardTint.health.opacity(0.20)
                        )
                        .frame(maxWidth: .infinity)
                }
            }

            Button(action: { viewModel.incrementWater() }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Log 16 oz")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.CardTint.health.opacity(0.18))
                )
                .foregroundColor(EquilibriumColor.CardTint.health)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(EquilibriumColor.CardTint.health.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var displayedGlasses: Int {
        let h = viewModel.healthSnapshot
        if h.waterOunces > 0 {
            return min(8, Int(h.waterOunces / 16))
        }
        return min(8, viewModel.todayWellness.waterGlasses)
    }

    // MARK: - Sleep + energy

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("SLEEP — SELF REPORT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                Spacer()
                Text(String(format: "%.1f h", viewModel.todayWellness.sleepHours))
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
            }
            .foregroundColor(EquilibriumColor.CardTint.health)

            Slider(
                value: Binding(
                    get: { viewModel.todayWellness.sleepHours },
                    set: { viewModel.todayWellness.sleepHours = $0; viewModel.saveWellness() }
                ),
                in: 0...12,
                step: 0.5
            )
            .tint(EquilibriumColor.CardTint.health)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(EquilibriumColor.CardTint.health.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("ENERGY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
            }
            .foregroundColor(EquilibriumColor.CardTint.health)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { level in
                    energyButton(level: level)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(EquilibriumColor.CardTint.health.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func energyButton(level: Int) -> some View {
        let isFilled = viewModel.todayWellness.energyLevel >= level
        return Button(action: { viewModel.setEnergy(level) }) {
            Circle()
                .fill(isFilled ? EquilibriumColor.CardTint.health : EquilibriumColor.primaryText.opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay(
                    Text("\(level)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isFilled ? .black : EquilibriumColor.primaryText)
                )
        }
    }

    // MARK: - Breathing pill

    private var breathingPill: some View {
        Button(action: { showBreathing = true }) {
            ZStack {
                Circle()
                    .fill(EquilibriumColor.CardTint.health)
                    .frame(width: 56, height: 56)
                    .shadow(color: EquilibriumColor.CardTint.health.opacity(0.45), radius: 16, y: 4)
                Image(systemName: "wind")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
