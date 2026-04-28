import SwiftUI

struct BirthdayCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var birthdayService = BirthdayService.shared

    @State private var selectedDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(alignment: .leading, spacing: 22) {
                    Text("WHEN WERE YOU BORN?")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(EquilibriumColor.CardTint.spiritual)

                    Text("Maria uses your birthday for horoscope and rhythm — never shared.")
                        .font(.system(size: 13))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    DatePicker(
                        "Birthday",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.wheel)
                    .tint(EquilibriumColor.CardTint.spiritual)
                    .colorScheme(.dark)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    let zodiac = Zodiac.from(date: selectedDate)
                    HStack(spacing: 12) {
                        Text(zodiac.glyph)
                            .font(.system(size: 38))
                            .foregroundColor(EquilibriumColor.CardTint.spiritual)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zodiac.label)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(EquilibriumColor.primaryText)
                            Text(zodiac.element)
                                .font(.system(size: 12))
                                .foregroundColor(EquilibriumColor.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(EquilibriumColor.CardTint.spiritual.opacity(0.12))
                    )

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Birthday")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        birthdayService.set(selectedDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(EquilibriumColor.CardTint.spiritual)
                }
            }
            .onAppear {
                if let existing = birthdayService.birthday {
                    selectedDate = existing
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.spiritual.opacity(0.22),
                    EquilibriumColor.CardTint.spiritual.opacity(0.05),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }
}
