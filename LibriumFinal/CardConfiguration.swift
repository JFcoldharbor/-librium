//
//  CardConfiguration.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//


import SwiftUI

// MARK: - Card Configuration Protocol
protocol CardConfiguration {
    var totalCards: Int { get }
    func getCardTitle(for cardNumber: Int) -> String
    func getCardContent(for cardNumber: Int) -> AnyView
    func getCardColor(for cardNumber: Int) -> Color
}

// MARK: - Work Hub Card Configuration
struct WorkHubCardConfig: CardConfiguration {
    let totalCards: Int = 4
    
    func getCardTitle(for cardNumber: Int) -> String {
        switch cardNumber {
        case 1: return "Today's Top Priorities"
        case 2: return "Work Goals & Ongoing Projects"
        case 3: return "Financials & Performance"
        case 4: return "Vision Board Progress"
        default: return "Unknown"
        }
    }
    
    func getCardContent(for cardNumber: Int) -> AnyView {
        switch cardNumber {
        case 1: return AnyView(WorkPrioritiesContent())
        case 2: return AnyView(WorkGoalsContent())
        case 3: return AnyView(WorkFinancialsContent())
        case 4: return AnyView(WorkVisionContent())
        default: return AnyView(Text("Unknown Card").foregroundColor(.white))
        }
    }
    
    func getCardColor(for cardNumber: Int) -> Color {
        switch cardNumber {
        case 1: return .orange
        case 2: return .green
        case 3: return .blue
        case 4: return .purple
        default: return .gray
        }
    }
}

// MARK: - Life Hub Card Configuration
struct LifeHubCardConfig: CardConfiguration {
    let totalCards: Int = 7
    
    func getCardTitle(for cardNumber: Int) -> String {
        switch cardNumber {
        case 1: return "Balance Meter"
        case 2: return "Wellness Overview"
        case 3: return "AI Insights"
        case 4: return "Vision Board Progress"
        case 5: return "Social & Connections"
        case 6: return "Motivational Quote"
        case 7: return "Balance Calendar"
        default: return "Unknown"
        }
    }
    
    func getCardContent(for cardNumber: Int) -> AnyView {
        switch cardNumber {
        case 1: return AnyView(BalanceMeterContent())
        case 2: return AnyView(WellnessOverviewContent())
        case 3: return AnyView(AIInsightsContent())
        case 4: return AnyView(LifeVisionContent())
        case 5: return AnyView(SocialConnectionsContent())
        case 6: return AnyView(MotivationalContent())
        case 7: return AnyView(BalanceCalendarContent())
        default: return AnyView(Text("Unknown Card").foregroundColor(.white))
        }
    }
    
    func getCardColor(for cardNumber: Int) -> Color {
        switch cardNumber {
        case 1: return .cyan
        case 2: return .mint
        case 3: return .indigo
        case 4: return .purple
        case 5: return .pink
        case 6: return .yellow
        case 7: return .teal
        default: return .gray
        }
    }
}

// MARK: - Generic Navigation State Management
class GenericNavigationState: ObservableObject {
    @Published var currentCard: Int = 1
    @Published var isAnimating: Bool = false
    @Published var previousCard: Int = 1
    
    private let cardConfig: CardConfiguration
    
    init(cardConfig: CardConfiguration) {
        self.cardConfig = cardConfig
    }
    
    var totalCards: Int {
        return cardConfig.totalCards
    }
    
    var canGoUp: Bool {
        return currentCard > 1
    }
    
    var canGoDown: Bool {
        return currentCard < totalCards
    }
    
    func navigateDown() {
        guard canGoDown && !isAnimating else { return }
        
        isAnimating = true
        previousCard = currentCard
        currentCard += 1
        
        // Reset animation state after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnimating = false
        }
    }
    
    func navigateUp() {
        guard canGoUp && !isAnimating else { return }
        
        isAnimating = true
        previousCard = currentCard
        currentCard -= 1
        
        // Reset animation state after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnimating = false
        }
    }
    
    func getCardTitle(for cardNumber: Int) -> String {
        return cardConfig.getCardTitle(for: cardNumber)
    }
    
    func getCardContent(for cardNumber: Int) -> AnyView {
        return cardConfig.getCardContent(for: cardNumber)
    }
    
    func getCardColor(for cardNumber: Int) -> Color {
        return cardConfig.getCardColor(for: cardNumber)
    }
}

// MARK: - Position Indicator Component
struct PositionIndicator: View {
    let currentCard: Int
    let totalCards: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalCards, id: \.self) { card in
                Circle()
                    .fill(card == currentCard ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(card == currentCard ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentCard)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentCard) of \(totalCards)")
    }
}

// MARK: - Navigation Arrows
struct NavigationArrows: View {
    let canGoUp: Bool
    let canGoDown: Bool
    
    var body: some View {
        VStack {
            if canGoUp {
                Image(systemName: "chevron.up")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                    .opacity(0.7)
            } else {
                Spacer()
                    .frame(height: 20)
            }
            
            Spacer()
            
            if canGoDown {
                Image(systemName: "chevron.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                    .opacity(0.7)
            } else {
                Spacer()
                    .frame(height: 20)
            }
        }
    }
}

// MARK: - Generic Card Component
struct GenericHubCard: View {
    let cardNumber: Int
    let title: String
    let content: AnyView
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            content
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Work Hub Content Views
struct WorkPrioritiesContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("High Priority Tasks")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Review quarterly report")
                Text("• Call client about proposal")
                Text("• Team meeting at 2 PM")
                Text("• Respond to urgent emails")
            }
            .foregroundColor(.white)
        }
    }
}

struct WorkGoalsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Goals")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Q4 Revenue Target: 75%")
                Text("• Project Alpha: On Track")
                Text("• Team Training: Scheduled")
                Text("• Process Improvement: In Progress")
            }
            .foregroundColor(.white)
        }
    }
}

struct WorkFinancialsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Financial Overview")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Monthly Revenue: $45K")
                Text("• YTD Performance: +12%")
                Text("• Pending Invoices: 3")
                Text("• Budget Utilization: 68%")
            }
            .foregroundColor(.white)
        }
    }
}

struct WorkVisionContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vision & Long-term")
                .font(.headline)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Annual Goal Progress: 67%")
                Text("• Career Development: Active")
                Text("• Skill Building: On Track")
                Text("• Vision Board Items: 4/7")
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - Life Hub Content Views
struct BalanceMeterContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overall Balance Score: 68%")
                .font(.headline)
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Work")
                    Spacer()
                    Text("45%")
                }
                HStack {
                    Text("Self-care")
                    Spacer()
                    Text("25%")
                }
                HStack {
                    Text("Social")
                    Spacer()
                    Text("20%")
                }
                HStack {
                    Text("Rest")
                    Spacer()
                    Text("10%")
                }
            }
            .foregroundColor(.white)
        }
    }
}

struct WellnessOverviewContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Physical & Mental Health")
                .font(.headline)
                .foregroundColor(.mint)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Steps: 8,247 / 10,000")
                Text("• Sleep: 7.2 hours")
                Text("• Mood: 😊 Good")
                Text("• Hydration: 6/8 glasses")
            }
            .foregroundColor(.white)
        }
    }
}

struct AIInsightsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights & Trends")
                .font(.headline)
                .foregroundColor(.indigo)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 Your energy peaks at 10 AM")
                Text("📈 Sleep quality improving this week")
                Text("⚠️ Work hours trending high")
                Text("🚶‍♂️ Try a 10-minute walk today")
            }
            .foregroundColor(.white)
        }
    }
}

struct LifeVisionContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Goals Progress")
                .font(.headline)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Learn Spanish: 45%")
                Text("• Run Marathon: Training Week 8")
                Text("• Read 24 Books: 18/24")
                Text("• Family Vacation: Planned")
            }
            .foregroundColor(.white)
        }
    }
}

struct SocialConnectionsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Relationships & Social")
                .font(.headline)
                .foregroundColor(.pink)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Last call to Mom: 2 days ago")
                Text("• Friend meetup: This Saturday")
                Text("• Birthday reminder: Tom (June 25)")
                Text("• Social events this week: 2")
            }
            .foregroundColor(.white)
        }
    }
}

struct MotivationalContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Inspiration")
                .font(.headline)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("\"Progress, not perfection.\"")
                    .font(.title3)
                    .italic()
                    .foregroundColor(.yellow)
                
                Text("Today's Challenge:")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text("Take 5 deep breaths before your next meeting")
                    .foregroundColor(.white)
            }
        }
    }
}

struct BalanceCalendarContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Work-Life Calendar")
                .font(.headline)
                .foregroundColor(.teal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 9:00 AM - Team standup (Work)")
                Text("• 12:00 PM - Lunch with Sarah (Personal)")
                Text("• 3:00 PM - Yoga class (Wellness)")
                Text("• 6:00 PM - Family dinner (Personal)")
            }
            .foregroundColor(.white)
        }
    }
}

// MARK: - Generic Vertical Navigation Container
struct GenericVerticalNavigation: View {
    @StateObject private var navigationState: GenericNavigationState
    @State private var dragOffset: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    
    // Gesture thresholds
    private let swipeThreshold: CGFloat = 120
    private let velocityThreshold: CGFloat = 800
    
    init(cardConfig: CardConfiguration) {
        self._navigationState = StateObject(wrappedValue: GenericNavigationState(cardConfig: cardConfig))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Card Container
                VStack(spacing: 0) {
                    // Main card area
                    GenericHubCard(
                        cardNumber: navigationState.currentCard,
                        title: navigationState.getCardTitle(for: navigationState.currentCard),
                        content: navigationState.getCardContent(for: navigationState.currentCard),
                        accentColor: navigationState.getCardColor(for: navigationState.currentCard)
                    )
                    .offset(y: dragOffset + bounceOffset)
                    .animation(.easeOut(duration: 0.3), value: navigationState.currentCard)
                    .animation(.easeOut(duration: 0.2), value: bounceOffset)
                    
                    // Bottom indicators
                    HStack {
                        PositionIndicator(
                            currentCard: navigationState.currentCard,
                            totalCards: navigationState.totalCards
                        )
                        
                        Spacer()
                        
                        Text("\(navigationState.currentCard) of \(navigationState.totalCards)")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                
                // Navigation arrows
                HStack {
                    Spacer()
                    NavigationArrows(
                        canGoUp: navigationState.canGoUp,
                        canGoDown: navigationState.canGoDown
                    )
                    .padding(.trailing, 16)
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only handle vertical gestures
                    if abs(value.translation.y) > abs(value.translation.x) {
                        dragOffset = value.translation.y * 0.3 // Dampen the drag
                    }
                }
                .onEnded { value in
                    let translation = value.translation.y
                    let velocity = value.velocity.y
                    
                    // Reset drag offset
                    dragOffset = 0
                    
                    // Check if gesture meets thresholds
                    let meetsDistanceThreshold = abs(translation) > swipeThreshold
                    let meetsVelocityThreshold = abs(velocity) > velocityThreshold
                    
                    if meetsDistanceThreshold || meetsVelocityThreshold {
                        // Determine direction and navigate
                        if translation < 0 && navigationState.canGoDown {
                            // Swipe up (negative) = go down in stack
                            navigationState.navigateDown()
                            generateHapticFeedback()
                        } else if translation > 0 && navigationState.canGoUp {
                            // Swipe down (positive) = go up in stack
                            navigationState.navigateUp()
                            generateHapticFeedback()
                        } else {
                            // Hit boundary - bounce back
                            performBounceAnimation()
                            generateBoundaryHaptic()
                        }
                    } else {
                        // Insufficient swipe - bounce back
                        performBounceAnimation()
                    }
                }
        )
        .onTapGesture { location in
            // Alternative navigation: tap top third to go up, bottom third to go down
            let screenHeight = UIScreen.main.bounds.height
            let tapY = location.y
            
            if tapY < screenHeight / 3 && navigationState.canGoUp {
                navigationState.navigateUp()
                generateHapticFeedback()
            } else if tapY > screenHeight * 2/3 && navigationState.canGoDown {
                navigationState.navigateDown()
                generateHapticFeedback()
            }
        }
        .accessibilityAction(.escape) {
            // Accessibility: Return to first card
            if navigationState.currentCard != 1 {
                navigationState.currentCard = 1
                generateHapticFeedback()
            }
        }
    }
    
    private func performBounceAnimation() {
        withAnimation(.easeOut(duration: 0.1)) {
            bounceOffset = dragOffset > 0 ? 10 : -10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.1)) {
                bounceOffset = 0
            }
        }
    }
    
    private func generateHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func generateBoundaryHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Hub-Specific Implementations
struct WorkHubNavigation: View {
    var body: some View {
        GenericVerticalNavigation(cardConfig: WorkHubCardConfig())
    }
}

struct LifeHubNavigation: View {
    var body: some View {
        GenericVerticalNavigation(cardConfig: LifeHubCardConfig())
    }
}

// MARK: - Test/Preview Components
struct NavigationTest: View {
    @State private var selectedHub: String = "Work"
    
    var body: some View {
        VStack {
            // Hub selector for testing
            Picker("Hub", selection: $selectedHub) {
                Text("Work Hub").tag("Work")
                Text("Life Hub").tag("Life")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Display selected hub
            if selectedHub == "Work" {
                WorkHubNavigation()
            } else {
                LifeHubNavigation()
            }
        }
    }
}

// MARK: - Preview
struct GenericVerticalNavigation_Previews: PreviewProvider {
    static var previews: some View {
        NavigationTest()
    }
}