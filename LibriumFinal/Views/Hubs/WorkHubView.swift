import SwiftUI

struct WorkHubView: View {
    let geometry: GeometryProxy
    @Binding var cardIndex: Int
    @Binding var verticalOffset: CGFloat
    let isActive: Bool

    @StateObject private var viewModel = WorkHubViewModel()

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            if isActive {
                ZStack {
                    WorkCalendarCard(
                        snapshot: viewModel.calendarSnapshot,
                        accessState: viewModel.calendarAccess
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(y: CGFloat(0 - (cardIndex + 1)) * geometry.size.height + verticalOffset)

                    WorkMainCard(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: CGFloat(1 - (cardIndex + 1)) * geometry.size.height + verticalOffset)

                    WorkFinancialCard()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: CGFloat(2 - (cardIndex + 1)) * geometry.size.height + verticalOffset)

                    WorkNetworkingCard(
                        snapshot: viewModel.relationshipSnapshot,
                        calendarAccess: viewModel.calendarAccess,
                        contactsAccess: viewModel.contactsAccess
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(y: CGFloat(3 - (cardIndex + 1)) * geometry.size.height + verticalOffset)
                }
            } else {
                WorkMainCard(viewModel: viewModel)
            }
        }
        .clipped()
        .task(id: isActive) {
            if isActive {
                await viewModel.refreshIfActive()
            }
        }
    }
}
