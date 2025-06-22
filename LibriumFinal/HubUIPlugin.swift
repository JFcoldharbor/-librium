//
//  HubExtensionPlugin.swift
//  LibriumFinal
//
//  Extension Plugin that works WITH your existing Hub system
//

import SwiftUI
import Combine

// MARK: - Hub Extension Plugin (Works with existing system)
struct HubExtensionPlugin: View {
    @ObservedObject var mariaBrain: MariaBrain
    @State private var currentPage: Int = 1 // Default to your existing Home
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Hub Indicator (extends your existing one)
                HStack {
                    Spacer()
                    ExtendedHubIndicator(currentHub: getCurrentHubType())
                    Spacer()
                }
                .padding(.top, 60)
                .zIndex(10)
                
                // Extended Hub Pages
                TabView(selection: $currentPage) {
                    // Life Hub Extension (Index 0)
                    LifeHubExtension()
                        .tag(0)
                    
                    // YOUR EXISTING HOME HUB (Index 1) - Unchanged
                    YourExistingHomeHubView(mariaBrain: mariaBrain)
                        .tag(1)
                    
                    // Work Hub Extension (Index 2)
                    WorkHubExtension()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
    }
    
    private func getCurrentHubType() -> ExtendedHubType {
        return ExtendedHubType(rawValue: currentPage) ?? .home
    }
}

// MARK: - Extended Hub Types (Won't conflict with your existing types)
enum ExtendedHubType: Int, CaseIterable {
    case life = 0
    case home = 1
    case work = 2
    
    var title: String {
        switch self {
        case .life: return "Life Balance"
        case .home: return "FINALE Home"  // Your existing home
        case .work: return "Work Focus"
        }
    }
    
    var color: Color {
        switch self {
        case .life: return .mint
        case .home: return .blue
        case .work: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .life: return "heart.fill"
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        }
    }
}

// MARK: - Extended Hub Indicator (Won't conflict)
struct ExtendedHubIndicator: View {
    let currentHub: ExtendedHubType
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(ExtendedHubType.allCases, id: \.self) { hub in
                Circle()
                    .fill(hub == currentHub ? hub.color : Color.gray.opacity(0.3))
                    .frame(width: hub == currentHub ? 10 : 8, height: hub == currentHub ? 10 : 8)
                    .scaleEffect(hub == currentHub ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentHub)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
                .blur(radius: 10)
        )
    }
}

// MARK: - Your Existing Home Hub (Placeholder - Use your actual implementation)
struct YourExistingHomeHubView: View {
    @ObservedObject var mariaBrain: MariaBrain
    
    var body: some View {
        // THIS IS WHERE YOUR EXISTING HOME HUB GOES
        // Replace this with your actual HomeHubView implementation
        
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Your existing header
                Text("FINALE Home")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Your existing AI Orb
                BlueOrbSwiftUI(isSpeaking: false)
                    .frame(width: 280, height: 280)
                
                // Your existing controls
                Text("How can I help you today?")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Navigation hints to new hubs
                HStack(spacing: 60) {
                    ExtensionHint(
                        icon: "heart.fill",
                        label: "Life Hub",
                        direction: "Swipe →",
                        color: .mint
                    )
                    
                    ExtensionHint(
                        icon: "briefcase.fill",
                        label: "Work Hub",
                        direction: "← Swipe",
                        color: .orange
                    )
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Life Hub Extension
struct LifeHubExtension: View {
    @StateObject private var cardManager = CardManager(cards: lifeCards)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                ExtensionHeader(
                    title: "Life Balance",
                    subtitle: "Today's Wellness",
                    icon: "heart.fill",
                    color: .mint
                )
                
                // Card Navigation
                CardNavigationView(manager: cardManager)
            }
        }
    }
    
    private let lifeCards: [CardData] = [
        CardData(id: 1, title: "Balance Meter", color: .cyan, content: .balanceMeter),
        CardData(id: 2, title: "Wellness Overview", color: .mint, content: .wellness),
        CardData(id: 3, title: "AI Insights", color: .indigo, content: .aiInsights),
        CardData(id: 4, title: "Vision Board", color: .purple, content: .vision),
        CardData(id: 5, title: "Social Connections", color: .pink, content: .social),
        CardData(id: 6, title: "Daily Inspiration", color: .yellow, content: .motivation),
        CardData(id: 7, title: "Balance Calendar", color: .teal, content: .calendar)
    ]
}

// MARK: - Work Hub Extension
struct WorkHubExtension: View {
    @StateObject private var cardManager = CardManager(cards: workCards)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                ExtensionHeader(
                    title: "Work Focus",
                    subtitle: "4 Priority Tasks",
                    icon: "briefcase.fill",
                    color: .orange
                )
                
                // Card Navigation
                CardNavigationView(manager: cardManager)
            }
        }
    }
    
    private let workCards: [CardData] = [
        CardData(id: 1, title: "Priority Tasks", color: .orange, content: .tasks),
        CardData(id: 2, title: "Goals & Projects", color: .green, content: .projects),
        CardData(id: 3, title: "Financials", color: .blue, content: .financials),
        CardData(id: 4, title: "Vision Board", color: .purple, content: .workVision)
    ]
}

// MARK: - Card Management System
class CardManager: ObservableObject {
    @Published var currentCardIndex: Int = 0
    @Published var isAnimating: Bool = false
    
    let cards: [CardData]
    
    init(cards: [CardData]) {
        self.cards = cards
    }
    
    var currentCard: CardData {
        cards[currentCardIndex]
    }
    
    var canGoUp: Bool {
        currentCardIndex > 0
    }
    
    var canGoDown: Bool {
        currentCardIndex < cards.count - 1
    }
    
    func navigateUp() {
        guard canGoUp && !isAnimating else { return }
        
        isAnimating = true
        currentCardIndex -= 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnimating = false
        }
    }
    
    func navigateDown() {
        guard canGoDown && !isAnimating else { return }
        
        isAnimating = true
        currentCardIndex += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnimating = false
        }
    }
}

// MARK: - Card Data Structure
struct CardData: Identifiable {
    let id: Int
    let title: String
    let color: Color
    let content: CardContentType
}

enum CardContentType {
    case balanceMeter, wellness, aiInsights, vision, social, motivation, calendar
    case tasks, projects, financials, workVision
}

// MARK: - Supporting Components

struct ExtensionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @State private var currentTime = Date()
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(currentTime, style: .time)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(currentTime, formatter: dayFormatter)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            HStack {
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

struct ExtensionHint: View {
    let icon: String
    let label: String
    let direction: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 24))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(direction)
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.6))
        }
    }
}

struct CardNavigationView: View {
    @ObservedObject var manager: CardManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Content
            ScrollView {
                VStack(spacing: 20) {
                    CardContentView(
                        card: manager.currentCard,
                        contentType: manager.currentCard.content
                    )
                }
                .padding()
            }
            
            // Navigation Controls
            HStack {
                // Position Indicator
                HStack(spacing: 8) {
                    ForEach(0..<manager.cards.count, id: \.self) { index in
                        Circle()
                            .fill(index == manager.currentCardIndex ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == manager.currentCardIndex ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: manager.currentCardIndex)
                    }
                }
                
                Spacer()
                
                Text("\(manager.currentCardIndex + 1) of \(manager.cards.count)")
                    .foregroundColor(.gray)
                    .font(.caption)
                
                Spacer()
                
                // Navigation Arrows
                VStack(spacing: 8) {
                    Button(action: manager.navigateUp) {
                        Image(systemName: "chevron.up")
                            .foregroundColor(manager.canGoUp ? .blue : .gray.opacity(0.3))
                    }
                    .disabled(!manager.canGoUp)
                    
                    Button(action: manager.navigateDown) {
                        Image(systemName: "chevron.down")
                            .foregroundColor(manager.canGoDown ? .blue : .gray.opacity(0.3))
                    }
                    .disabled(!manager.canGoDown)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let translation = value.translation.y
                    let velocity = value.velocity.y
                    
                    if abs(translation) > 50 || abs(velocity) > 500 {
                        if translation < 0 && manager.canGoDown {
                            manager.navigateDown()
                        } else if translation > 0 && manager.canGoUp {
                            manager.navigateUp()
                        }
                    }
                }
        )
    }
}

struct CardContentView: View {
    let card: CardData
    let contentType: CardContentType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(card.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Content based on type
            Group {
                switch contentType {
                case .balanceMeter:
                    BalanceMeterContent()
                case .wellness:
                    WellnessContent()
                case .aiInsights:
                    AIInsightsContent()
                case .vision:
                    VisionContent()
                case .social:
                    SocialContent()
                case .motivation:
                    MotivationContent()
                case .calendar:
                    CalendarContent()
                case .tasks:
                    TasksContent()
                case .projects:
                    ProjectsContent()
                case .financials:
                    FinancialsContent()
                case .workVision:
                    WorkVisionContent()
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 400, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(card.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Simple Content Views (Lightweight implementations)

struct BalanceMeterContent: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Overall Balance: 68%")
                .font(.title2)
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Work: 45%")
                Text("• Self-care: 25%")
                Text("• Social: 20%")
                Text("• Rest: 10%")
            }
            .foregroundColor(.white)
        }
    }
}

struct WellnessContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• Steps: 8,247 / 10,000")
            Text("• Sleep: 7.2 hours")
            Text("• Mood: 😊 Good")
            Text("• Hydration: 6/8 glasses")
        }
        .foregroundColor(.white)
    }
}

struct AIInsightsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Energy peaks at 10 AM")
            Text("📈 Sleep quality improving")
            Text("⚠️ Work hours trending high")
            Text("🚶‍♂️ Try a 10-minute walk")
        }
        .foregroundColor(.white)
    }
}

struct VisionContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• Learn Spanish: 45%")
            Text("• Run Marathon: Week 8/12")
            Text("• Read 24 Books: 18/24")
            Text("• Family Vacation: Planned")
        }
        .foregroundColor(.white)
    }
}

struct SocialContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• Call Mom (2 days ago)")
            Text("• Meetup with Sarah (Saturday)")
            Text("• Tom's Birthday (June 25)")
            Text("• 12 calls this week")
        }
        .foregroundColor(.white)
    }
}

struct MotivationContent: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("\"Progress, not perfection.\"")
                .font(.title3)
                .italic()
                .foregroundColor(.yellow)
            
            Text("Today's Challenge:")
                .foregroundColor(.white.opacity(0.7))
            
            Text("Take 5 deep breaths before your next meeting")
                .foregroundColor(.white)
        }
        .multilineTextAlignment(.center)
    }
}

struct CalendarContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• 9:00 AM - Team standup")
            Text("• 12:00 PM - Lunch with Sarah")
            Text("• 3:00 PM - Yoga class")
            Text("• 6:00 PM - Family dinner")
        }
        .foregroundColor(.white)
    }
}

struct TasksContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🔴 Review Q4 Report (2h)")
            Text("🔴 Client Call (3 PM)")
            Text("🔴 Submit Proposal (EOD)")
            Text("🟡 5 Medium Priority")
        }
        .foregroundColor(.white)
    }
}

struct ProjectsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• Q4 Revenue: 85% ($850K/$1M)")
            Text("• New Clients: 80% (12/15)")
            Text("• Mobile App v2.0: 65%")
            Text("• Marketing Campaign: 30%")
        }
        .foregroundColor(.white)
    }
}

struct FinancialsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• Revenue: $125.4K (+12%)")
            Text("• Expenses: $45.2K (-5%)")
            Text("• Pending Invoices: 8")
            Text("• Budget: 68% utilized")
        }
        .foregroundColor(.white)
    }
}

struct WorkVisionContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• Industry Leader: 70%")
            Text("• Team of 50: 40%")
            Text("• Global Reach: 30%")
            Text("• Award Winner: ✅ Complete")
        }
        .foregroundColor(.white)
    }
}
