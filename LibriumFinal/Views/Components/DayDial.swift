import SwiftUI

struct DayDial: View {
    let events: [CalendarEventSummary]
    let now: Date
    let tint: Color

    private let dialSize: CGFloat = 240
    private let arcThickness: CGFloat = 12

    var body: some View {
        ZStack {
            ringTrack

            ForEach(timedEvents) { event in
                EventArcShape(
                    startAngle: angle(for: event.startDate),
                    endAngle: angle(for: event.endDate),
                    thickness: arcThickness
                )
                .fill(arcColor(for: event))
            }

            hourTicks

            nowHand

            centerStack
        }
        .frame(width: dialSize, height: dialSize)
    }

    private var ringTrack: some View {
        Circle()
            .stroke(tint.opacity(0.10), lineWidth: arcThickness)
            .frame(width: dialSize - arcThickness, height: dialSize - arcThickness)
    }

    private var hourTicks: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { hour in
                Rectangle()
                    .fill(EquilibriumColor.tertiaryText.opacity(hour % 6 == 0 ? 0.6 : 0.25))
                    .frame(width: hour % 6 == 0 ? 1.5 : 1, height: hour % 6 == 0 ? 8 : 4)
                    .offset(y: -(dialSize / 2 - arcThickness - 6))
                    .rotationEffect(.degrees(Double(hour) * 15))
            }
            anchorLabel(text: "12a", angle: 0)
            anchorLabel(text: "6a", angle: 90)
            anchorLabel(text: "12p", angle: 180)
            anchorLabel(text: "6p", angle: 270)
        }
    }

    private func anchorLabel(text: String, angle: Double) -> some View {
        let radius = dialSize / 2 - arcThickness - 22
        let radians = (angle - 90) * .pi / 180
        let x = cos(radians) * radius
        let y = sin(radians) * radius
        return Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(EquilibriumColor.tertiaryText)
            .offset(x: x, y: y)
    }

    private var nowHand: some View {
        let nowAngle = angle(for: now)
        return ZStack {
            Rectangle()
                .fill(tint)
                .frame(width: 2, height: dialSize / 2 - arcThickness - 4)
                .offset(y: -(dialSize / 2 - arcThickness - 4) / 2)
                .rotationEffect(.degrees(nowAngle))
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
        }
    }

    private var centerStack: some View {
        VStack(spacing: 2) {
            Text("\(timedEvents.count)")
                .font(.system(size: 56, weight: .bold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
            Text(timedEvents.count == 1 ? "meeting" : "meetings")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }

    // MARK: - Helpers

    private var timedEvents: [CalendarEventSummary] {
        events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
    }

    private func angle(for date: Date) -> Double {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = Double(comps.hour ?? 0) * 60 + Double(comps.minute ?? 0)
        return (minutes / 1440.0) * 360.0
    }

    private func arcColor(for event: CalendarEventSummary) -> Color {
        if event.endDate < now {
            return tint.opacity(0.25)
        }
        if event.startDate <= now && now <= event.endDate {
            return tint
        }
        return tint.opacity(0.65)
    }
}

private struct EventArcShape: Shape {
    let startAngle: Double
    let endAngle: Double
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius - thickness

        let start = Angle.degrees(startAngle - 90)
        let end = Angle.degrees(endAngle - 90)

        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
