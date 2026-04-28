import Foundation

struct MoonPhase: Equatable {
    let phase: Double          // 0.0 ... 1.0 (0 = new, 0.5 = full)
    let illumination: Double   // 0.0 ... 1.0 fraction of disc lit
    let kind: Kind
    let asOf: Date

    enum Kind: String {
        case new, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent

        var label: String {
            switch self {
            case .new: return "New Moon"
            case .waxingCrescent: return "Waxing Crescent"
            case .firstQuarter: return "First Quarter"
            case .waxingGibbous: return "Waxing Gibbous"
            case .full: return "Full Moon"
            case .waningGibbous: return "Waning Gibbous"
            case .lastQuarter: return "Last Quarter"
            case .waningCrescent: return "Waning Crescent"
            }
        }
    }

    static func current(now: Date = Date()) -> MoonPhase {
        // Reference new moon: 2000-01-06 18:14 UTC
        let referenceJD = 2_451_550.1
        let synodicMonth = 29.530588853

        let julianDay = now.timeIntervalSince1970 / 86_400.0 + 2_440_587.5
        let daysSinceRef = julianDay - referenceJD
        var phase = (daysSinceRef / synodicMonth).truncatingRemainder(dividingBy: 1.0)
        if phase < 0 { phase += 1.0 }

        let illumination = 0.5 * (1.0 - cos(2.0 * .pi * phase))
        return MoonPhase(
            phase: phase,
            illumination: illumination,
            kind: kindFor(phase: phase),
            asOf: now
        )
    }

    private static func kindFor(phase: Double) -> Kind {
        switch phase {
        case 0..<0.03, 0.97...1.0: return .new
        case 0.03..<0.22: return .waxingCrescent
        case 0.22..<0.28: return .firstQuarter
        case 0.28..<0.47: return .waxingGibbous
        case 0.47..<0.53: return .full
        case 0.53..<0.72: return .waningGibbous
        case 0.72..<0.78: return .lastQuarter
        case 0.78..<0.97: return .waningCrescent
        default: return .new
        }
    }
}
