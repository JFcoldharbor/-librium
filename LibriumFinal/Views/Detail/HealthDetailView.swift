import SwiftUI

struct HealthDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: HealthSnapshot = .empty
    @State private var loading: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if loading {
                            HStack {
                                Spacer()
                                ProgressView().tint(EquilibriumColor.primaryText)
                                Spacer()
                            }
                            .padding(.top, 80)
                        } else {
                            activitySection
                            sleepSection
                            heartSection
                            mindfulnessSection
                            bodySection
                            vitalsSection
                            nutritionSection
                            Spacer().frame(height: 60)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        loading = true
        snapshot = await HealthKitService.shared.loadSnapshot()
        loading = false
    }

    // MARK: - Activity

    private var activitySection: some View {
        section(title: "ACTIVITY", icon: "flame.fill", tint: Color.orange) {
            VStack(spacing: 12) {
                statRow(label: "Move", value: "\(snapshot.activity.activeKcal) kcal", emphasis: true, tint: Color.red)
                statRow(label: "Exercise", value: "\(snapshot.activity.exerciseMinutes) min", tint: Color.green)
                statRow(label: "Stand", value: "\(snapshot.activity.standHours) hrs", tint: Color.cyan)
                Divider().background(EquilibriumColor.primaryText.opacity(0.1))
                statRow(label: "Steps", value: snapshot.activity.steps == 0 ? "—" : "\(snapshot.activity.steps.formatted())")
                statRow(label: "Distance", value: distanceLabel(snapshot.activity.distanceMeters))
                statRow(label: "Flights", value: snapshot.activity.flightsClimbed == 0 ? "—" : "\(snapshot.activity.flightsClimbed)")
                statRow(label: "Resting kcal", value: snapshot.activity.basalKcal == 0 ? "—" : "\(snapshot.activity.basalKcal)")
            }
        }
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        section(title: "SLEEP", icon: "bed.double.fill", tint: Color.indigo) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(formatHours(snapshot.sleep.totalHours))
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.primaryText)
                    Text("asleep last night")
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }

                if snapshot.sleep.totalHours > 0 {
                    sleepStageBar
                    HStack(spacing: 12) {
                        stageDot(label: "REM", hours: snapshot.sleep.remHours, color: Color.purple)
                        stageDot(label: "Deep", hours: snapshot.sleep.deepHours, color: Color.indigo)
                        stageDot(label: "Core", hours: snapshot.sleep.coreHours, color: Color.cyan)
                        if snapshot.sleep.awakeHours > 0 {
                            stageDot(label: "Awake", hours: snapshot.sleep.awakeHours, color: Color.orange)
                        }
                    }
                    if snapshot.sleep.inBedHours > snapshot.sleep.totalHours {
                        Text("In bed: \(formatHours(snapshot.sleep.inBedHours))")
                            .font(.system(size: 11))
                            .foregroundColor(EquilibriumColor.tertiaryText)
                    }
                } else {
                    Text("No sleep data tracked. Wear your watch overnight or log via Apple Health.")
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var sleepStageBar: some View {
        let total = max(0.001, snapshot.sleep.remHours + snapshot.sleep.deepHours + snapshot.sleep.coreHours + snapshot.sleep.awakeHours)
        GeometryReader { proxy in
            HStack(spacing: 1) {
                segment(width: proxy.size.width * CGFloat(snapshot.sleep.deepHours / total), color: Color.indigo)
                segment(width: proxy.size.width * CGFloat(snapshot.sleep.coreHours / total), color: Color.cyan)
                segment(width: proxy.size.width * CGFloat(snapshot.sleep.remHours / total), color: Color.purple)
                segment(width: proxy.size.width * CGFloat(snapshot.sleep.awakeHours / total), color: Color.orange)
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        Rectangle().fill(color).frame(width: max(0, width))
    }

    private func stageDot(label: String, hours: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(formatHours(hours))")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }

    // MARK: - Heart

    private var heartSection: some View {
        section(title: "HEART", icon: "heart.fill", tint: Color.red.opacity(0.85)) {
            VStack(spacing: 12) {
                statRow(label: "Resting", value: snapshot.heart.restingBpm == 0 ? "—" : "\(snapshot.heart.restingBpm) bpm", emphasis: true, tint: Color.red.opacity(0.85))
                statRow(label: "Walking avg", value: snapshot.heart.walkingAverageBpm == 0 ? "—" : "\(snapshot.heart.walkingAverageBpm) bpm")
                statRow(label: "Today's avg", value: snapshot.heart.averageBpm == 0 ? "—" : "\(snapshot.heart.averageBpm) bpm")
                statRow(label: "HRV (SDNN)", value: snapshot.heart.hrvMs == 0 ? "—" : String(format: "%.0f ms", snapshot.heart.hrvMs))
            }
        }
    }

    // MARK: - Mindfulness

    private var mindfulnessSection: some View {
        section(title: "MINDFULNESS", icon: "brain.head.profile", tint: Color.mint) {
            VStack(spacing: 12) {
                statRow(label: "Today", value: snapshot.mindfulness.minutes == 0 ? "—" : "\(snapshot.mindfulness.minutes) min", emphasis: true, tint: Color.mint)
                statRow(label: "Sessions", value: "\(snapshot.mindfulness.sessionCount)")
            }
        }
    }

    // MARK: - Body

    private var bodySection: some View {
        section(title: "BODY", icon: "figure.stand", tint: Color.purple) {
            VStack(spacing: 12) {
                statRow(label: "Weight", value: snapshot.body.weightLbs == 0 ? "—" : String(format: "%.1f lbs", snapshot.body.weightLbs))
                statRow(label: "Height", value: snapshot.body.heightInches == 0 ? "—" : heightLabel(snapshot.body.heightInches))
                statRow(label: "BMI", value: snapshot.body.bmi == 0 ? "—" : String(format: "%.1f", snapshot.body.bmi))
                statRow(label: "Body fat", value: snapshot.body.bodyFatPercent == 0 ? "—" : String(format: "%.1f%%", snapshot.body.bodyFatPercent))
            }
        }
    }

    // MARK: - Vitals

    private var vitalsSection: some View {
        section(title: "VITALS", icon: "lungs.fill", tint: Color.teal) {
            VStack(spacing: 12) {
                statRow(label: "Blood oxygen", value: snapshot.vitals.oxygenSaturationPercent == 0 ? "—" : String(format: "%.0f%%", snapshot.vitals.oxygenSaturationPercent))
                statRow(label: "Respiratory rate", value: snapshot.vitals.respiratoryRatePerMin == 0 ? "—" : String(format: "%.0f /min", snapshot.vitals.respiratoryRatePerMin))
                statRow(label: "Blood pressure", value: bloodPressureLabel)
            }
        }
    }

    // MARK: - Nutrition

    private var nutritionSection: some View {
        section(title: "NUTRITION", icon: "drop.fill", tint: Color.blue) {
            VStack(spacing: 12) {
                statRow(label: "Water", value: String(format: "%.1f oz", snapshot.waterOunces), tint: Color.blue)
            }
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(tint.opacity(0.18), lineWidth: 0.5)
                )
        )
    }

    private func statRow(label: String, value: String, emphasis: Bool = false, tint: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(EquilibriumColor.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: emphasis ? 16 : 14, weight: emphasis ? .semibold : .medium))
                .monospacedDigit()
                .foregroundColor(tint ?? EquilibriumColor.primaryText)
        }
    }

    private func formatHours(_ hours: Double) -> String {
        guard hours > 0 else { return "—" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func distanceLabel(_ meters: Double) -> String {
        guard meters > 0 else { return "—" }
        let miles = meters / 1609.34
        return String(format: "%.2f mi", miles)
    }

    private func heightLabel(_ inches: Double) -> String {
        let feet = Int(inches / 12)
        let remainder = Int(inches.truncatingRemainder(dividingBy: 12))
        return "\(feet)' \(remainder)\""
    }

    private var bloodPressureLabel: String {
        let s = snapshot.vitals.systolicBp
        let d = snapshot.vitals.diastolicBp
        if s == 0 || d == 0 { return "—" }
        return "\(s)/\(d)"
    }
}
