import SwiftUI

struct LifeHubView: View {
    let geometry: GeometryProxy
    @Binding var cardIndex: Int
    @Binding var verticalOffset: CGFloat
    let isActive: Bool

    @StateObject private var viewModel = LifeHubViewModel()

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            if isActive {
                ZStack {
                    LifeSpiritualCard(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: CGFloat(0 - (cardIndex + 1)) * geometry.size.height + verticalOffset)

                    LifeMainCard(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: CGFloat(1 - (cardIndex + 1)) * geometry.size.height + verticalOffset)

                    LifeWellnessCard(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(y: CGFloat(2 - (cardIndex + 1)) * geometry.size.height + verticalOffset)
                }
            } else {
                LifeMainCard(viewModel: viewModel)
            }
        }
        .clipped()
        .task(id: isActive) {
            if isActive {
                viewModel.loadAll()
            }
        }
    }
}
