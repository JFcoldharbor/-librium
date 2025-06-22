//
//  CardActionType.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//


import SwiftUI

// MARK: - Card Action Types
enum CardActionType {
    case complete
    case toggle
    case input
    case navigate
    case log
    case delete
}

// MARK: - Card Interaction Manager
class CardInteractionManager: ObservableObject {
    @Published var cardStates: [String: Any] = [:]
    @Published var isLoading: [String: Bool] = [:]
    @Published var lastAction: (type: CardActionType, cardId: String, data: Any?)?
    
    func handleAction(_ action: CardActionType, for cardId: String, with data: Any? = nil) {
        // Set loading state
        isLoading[cardId] = true
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.processAction(action, for: cardId, with: data)
            self.isLoading[cardId] = false
        }
        
        // Store for undo functionality
        lastAction = (action, cardId, data)
        
        // Generate appropriate haptic feedback
        generateHaptic(for: action)
    }
    
    private func processAction(_ action: CardActionType, for cardId: String, with data: Any?) {
        switch action {
        case .complete:
            cardStates["\(cardId)_completed"] = true
        case .toggle:
            let currentState = cardStates["\(cardId)_toggled"] as? Bool ?? false
            cardStates["\(cardId)_toggled"] = !currentState
        case .input:
            if let inputData = data {
                cardStates["\(cardId)_input"] = inputData
            }
        case .log:
            if let logData = data {
                cardStates["\(cardId)_logged"] = logData
            }
        case .navigate:
            // Handle navigation
            break
        case .delete:
            cardStates["\(cardId)_deleted"] = true
        }
    }
    
    func validateInput(_ input: Any, for field: String) -> Bool {
        // Basic validation examples
        if let text = input as? String {
            return !text.isEmpty && text.count <= 100
        }
        if let number = input as? Double {
            return number >= 0 && number <= 1000
        }
        return true
    }
    
    func undoLastAction() {
        guard let lastAction = lastAction else { return }
        
        // Revert the last action
        switch lastAction.type {
        case .complete:
            cardStates["\(lastAction.cardId)_completed"] = false
        case .toggle:
            let currentState = cardStates["\(lastAction.cardId)_toggled"] as? Bool ?? false
            cardStates["\(lastAction.cardId)_toggled"] = !currentState
        case .delete:
            cardStates["\(lastAction.cardId)_deleted"] = false
        default:
            break
        }
        
        generateHaptic(for: .toggle) // Undo haptic
        self.lastAction = nil
    }
    
    private func generateHaptic(for action: CardActionType) {
        switch action {
        case .complete:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        case .toggle, .log:
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        case .delete:
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        default:
            break
        }
    }
    
    func getState<T>(for key: String, as type: T.Type) -> T? {
        return cardStates[key] as? T
    }
}

// MARK: - Interactive Card Components

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: CardActionType
    let cardId: String
    let color: Color
    @ObservedObject var manager: CardInteractionManager
    @State private var isPressed = false
    
    var isLoading: Bool {
        manager.isLoading[cardId] ?? false
    }
    
    var isCompleted: Bool {
        manager.getState(for: "\(cardId)_completed", as: Bool.self) ?? false
    }
    
    var body: some View {
        Button(action: {
            manager.handleAction(action, for: cardId)
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(isCompleted ? "Done" : title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isCompleted ? .green : color)
                    .opacity(isPressed ? 0.8 : 1.0)
            )
        }
        .disabled(isLoading || isCompleted)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
        .onLongPressGesture(minimumDuration: 0) { isPressing in
            isPressed = isPressing
        } perform: {}
    }
}

struct ToggleSwitch: View {
    let title: String
    let cardId: String
    @ObservedObject var manager: CardInteractionManager
    
    var isToggled: Bool {
        manager.getState(for: "\(cardId)_toggled", as: Bool.self) ?? false
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 16))
            
            Spacer()
            
            Button(action: {
                manager.handleAction(.toggle, for: cardId)
            }) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isToggled ? .green : .gray.opacity(0.3))
                    .frame(width: 50, height: 30)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 26, height: 26)
                            .offset(x: isToggled ? 10 : -10)
                    )
            }
            .animation(.easeInOut(duration: 0.2), value: isToggled)
        }
    }
}

struct DataInputField: View {
    let title: String
    let placeholder: String
    let cardId: String
    @ObservedObject var manager: CardInteractionManager
    @State private var inputText: String = ""
    @State private var isValid: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            
            TextField(placeholder, text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isValid ? .clear : .red, lineWidth: 2)
                )
                .onChange(of: inputText) { _, newValue in
                    isValid = manager.validateInput(newValue, for: "\(cardId)_input")
                    if isValid {
                        manager.handleAction(.input, for: cardId, with: newValue)
                    }
                }
        }
    }
}

struct SliderInput: View {
    let title: String
    let range: ClosedRange<Double>
    let cardId: String
    @ObservedObject var manager: CardInteractionManager
    @State private var value: Double = 5.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                Text("\(Int(value))")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .bold))
            }
            
            Slider(value: $value, in: range, step: 1.0)
                .accentColor(.blue)
                .onChange(of: value) { _, newValue in
                    manager.handleAction(.log, for: cardId, with: newValue)
                }
        }
    }
}

struct SwipeActionCard: View {
    let content: AnyView
    let cardId: String
    @ObservedObject var manager: CardInteractionManager
    @State private var offset: CGFloat = 0
    @State private var showingDeleteConfirmation = false
    
    var isDeleted: Bool {
        manager.getState(for: "\(cardId)_deleted", as: Bool.self) ?? false
    }
    
    var body: some View {
        if !isDeleted {
            content
                .offset(x: offset)
                .background(
                    HStack {
                        Spacer()
                        
                        // Delete action background
                        Rectangle()
                            .fill(.red)
                            .frame(width: min(abs(offset), 80))
                            .overlay(
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.white)
                                    .opacity(abs(offset) > 40 ? 1.0 : 0.0)
                            )
                    }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.x < 0 {
                                offset = value.translation.x
                            }
                        }
                        .onEnded { value in
                            if value.translation.x < -80 {
                                showingDeleteConfirmation = true
                            }
                            
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset = 0
                            }
                        }
                )
                .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        manager.handleAction(.delete, for: cardId)
                    }
                } message: {
                    Text("Are you sure you want to delete this item?")
                }
        }
    }
}

// MARK: - Enhanced Card Content with Interactions

struct InteractiveWorkPriorities: View {
    @StateObject private var manager = CardInteractionManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("High Priority Tasks")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 12) {
                SwipeActionCard(
                    content: AnyView(
                        HStack {
                            Text("• Review quarterly report")
                                .foregroundColor(.white)
                            Spacer()
                            QuickActionButton(
                                title: "Complete",
                                icon: "circle",
                                action: .complete,
                                cardId: "task1",
                                color: .orange,
                                manager: manager
                            )
                        }
                    ),
                    cardId: "task1",
                    manager: manager
                )
                
                SwipeActionCard(
                    content: AnyView(
                        HStack {
                            Text("• Call client about proposal")
                                .foregroundColor(.white)
                            Spacer()
                            QuickActionButton(
                                title: "Call",
                                icon: "phone.fill",
                                action: .navigate,
                                cardId: "task2",
                                color: .blue,
                                manager: manager
                            )
                        }
                    ),
                    cardId: "task2",
                    manager: manager
                )
                
                DataInputField(
                    title: "Add New Task",
                    placeholder: "Enter task description",
                    cardId: "newTask",
                    manager: manager
                )
            }
            
            if manager.lastAction != nil {
                Button("Undo Last Action") {
                    manager.undoLastAction()
                }
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
    }
}

struct InteractiveWellnessOverview: View {
    @StateObject private var manager = CardInteractionManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Physical & Mental Health")
                .font(.headline)
                .foregroundColor(.mint)
            
            VStack(alignment: .leading, spacing: 12) {
                SliderInput(
                    title: "Mood Level",
                    range: 1...10,
                    cardId: "mood",
                    manager: manager
                )
                
                SliderInput(
                    title: "Energy Level",
                    range: 1...10,
                    cardId: "energy",
                    manager: manager
                )
                
                ToggleSwitch(
                    title: "Workout Completed",
                    cardId: "workout",
                    manager: manager
                )
                
                HStack {
                    QuickActionButton(
                        title: "Log Water",
                        icon: "drop.fill",
                        action: .log,
                        cardId: "water",
                        color: .cyan,
                        manager: manager
                    )
                    
                    QuickActionButton(
                        title: "Log Meal",
                        icon: "fork.knife",
                        action: .log,
                        cardId: "meal",
                        color: .green,
                        manager: manager
                    )
                }
            }
        }
    }
}

// MARK: - Test View
struct CardInteractionTest: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Work Hub - Priority Tasks")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    InteractiveWorkPriorities()
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.8))
                        )
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Life Hub - Wellness")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    InteractiveWellnessOverview()
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.8))
                        )
                }
            }
            .padding()
        }
        .background(Color.black)
    }
}

// MARK: - Preview
struct CardInteractionSystem_Previews: PreviewProvider {
    static var previews: some View {
        CardInteractionTest()
    }
}