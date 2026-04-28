import SwiftUI
import UIKit

struct MinimalFastNavigation: View {
    @StateObject private var navigationState = NavigationStateViewModel()
    @State private var dragOffset: CGFloat = 0
    @State private var verticalDragOffset: CGFloat = 0
    @State private var activeGesture: GestureType = .none

    enum GestureType {
        case none, horizontal, vertical
    }

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    LifeHubView(
                        geometry: geometry,
                        cardIndex: $navigationState.lifeCardIndex,
                        verticalOffset: $verticalDragOffset,
                        isActive: navigationState.currentHub == 0
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)

                    HomeHubView(geometry: geometry)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    WorkHubView(
                        geometry: geometry,
                        cardIndex: $navigationState.workCardIndex,
                        verticalOffset: $verticalDragOffset,
                        isActive: navigationState.currentHub == 2
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .offset(x: -CGFloat(navigationState.currentHub) * geometry.size.width + dragOffset)
                .gesture(unifiedGesture(geometry: geometry))
                .animation(EquilibriumConfig.hubSwipeAnimation, value: navigationState.currentHub)
                .animation(EquilibriumConfig.dragOffsetAnimation, value: dragOffset)
                .animation(EquilibriumConfig.cardSwipeAnimation, value: verticalDragOffset)
            }

            VStack {
                Spacer()
                HubDots(currentIndex: navigationState.currentHub)
                    .padding(.bottom, 40)
            }

            // Floating Maria orb — visible on Life and Work hubs (Home already has the big orb)
            if navigationState.currentHub != EquilibriumConfig.homeHubIndex {
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        FloatingMariaOrb()
                            .padding(.leading, 20)
                            .padding(.bottom, 36)
                        Spacer()
                    }
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .animation(EquilibriumConfig.hubSwipeAnimation, value: navigationState.currentHub)
        .onAppear {
            navigationState.loadState()
        }
    }

    private func unifiedGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: EquilibriumConfig.dragMinimumDistance)
            .onChanged { value in
                if activeGesture == .none {
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)

                    if horizontal > vertical * EquilibriumConfig.horizontalDominanceRatio {
                        activeGesture = .horizontal
                    } else if vertical > horizontal && (navigationState.currentHub == 0 || navigationState.currentHub == 2) {
                        activeGesture = .vertical
                    }
                }

                switch activeGesture {
                case .horizontal:
                    handleHorizontalDrag(value: value)
                case .vertical:
                    handleVerticalDrag(value: value)
                case .none:
                    break
                }
            }
            .onEnded { value in
                switch activeGesture {
                case .horizontal:
                    handleHorizontalEnd(value: value)
                case .vertical:
                    handleVerticalEnd(value: value)
                case .none:
                    break
                }

                activeGesture = .none
            }
    }

    private func handleHorizontalDrag(value: DragGesture.Value) {
        var offset = value.translation.width

        if (navigationState.currentHub == 0 && offset > 0) ||
           (navigationState.currentHub == 2 && offset < 0) {
            offset *= EquilibriumConfig.edgeResistance
        }

        dragOffset = offset
    }

    private func handleHorizontalEnd(value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.width - value.translation.width

        withAnimation(EquilibriumConfig.hubSwipeAnimation) {
            if abs(velocity) > EquilibriumConfig.velocityThreshold {
                if velocity > 0 && navigationState.currentHub > 0 {
                    navigationState.currentHub -= 1
                    triggerHaptic(.medium)
                } else if velocity < 0 && navigationState.currentHub < EquilibriumConfig.hubCount - 1 {
                    navigationState.currentHub += 1
                    triggerHaptic(.medium)
                }
            } else if value.translation.width > EquilibriumConfig.swipeThreshold && navigationState.currentHub > 0 {
                navigationState.currentHub -= 1
                triggerHaptic(.medium)
            } else if value.translation.width < -EquilibriumConfig.swipeThreshold && navigationState.currentHub < EquilibriumConfig.hubCount - 1 {
                navigationState.currentHub += 1
                triggerHaptic(.medium)
            }

            dragOffset = 0
        }

        navigationState.saveState()
    }

    private func handleVerticalDrag(value: DragGesture.Value) {
        guard navigationState.currentHub == 0 || navigationState.currentHub == 2 else { return }

        var offset = value.translation.height
        let activeIndex = navigationState.currentHub == 0 ? navigationState.lifeCardIndex : navigationState.workCardIndex
        let activeMax = navigationState.currentHub == 0 ? EquilibriumConfig.lifeCardIndexMax : EquilibriumConfig.workCardIndexMax

        if (activeIndex == EquilibriumConfig.cardIndexMin && offset > 0) ||
           (activeIndex == activeMax && offset < 0) {
            offset *= EquilibriumConfig.edgeResistance
        }

        verticalDragOffset = offset
    }

    private func handleVerticalEnd(value: DragGesture.Value) {
        guard navigationState.currentHub == 0 || navigationState.currentHub == 2 else { return }

        withAnimation(EquilibriumConfig.cardSwipeAnimation) {
            if navigationState.currentHub == 0 {
                if value.translation.height < -EquilibriumConfig.swipeThreshold && navigationState.lifeCardIndex < EquilibriumConfig.lifeCardIndexMax {
                    navigationState.lifeCardIndex += 1
                    triggerHaptic(.light)
                } else if value.translation.height > EquilibriumConfig.swipeThreshold && navigationState.lifeCardIndex > EquilibriumConfig.cardIndexMin {
                    navigationState.lifeCardIndex -= 1
                    triggerHaptic(.light)
                }
            } else {
                if value.translation.height < -EquilibriumConfig.swipeThreshold && navigationState.workCardIndex < EquilibriumConfig.workCardIndexMax {
                    navigationState.workCardIndex += 1
                    triggerHaptic(.light)
                } else if value.translation.height > EquilibriumConfig.swipeThreshold && navigationState.workCardIndex > EquilibriumConfig.cardIndexMin {
                    navigationState.workCardIndex -= 1
                    triggerHaptic(.light)
                }
            }

            verticalDragOffset = 0
        }

        navigationState.saveState()
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
}
