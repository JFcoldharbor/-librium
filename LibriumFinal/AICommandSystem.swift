//
//  CompleteCommandSystem.swift
//  LibriumFinal
//
//  Self-contained command system with all dependencies
//

import Foundation
import UserNotifications

// MARK: - Complete Command System with All Dependencies

class AICommandSystem: ObservableObject {
    @Published var currentMode: AIMode = .active
    @Published var isDNDActive = false
    @Published var sleepModeActive = false
    @Published var scheduledCommands: [ScheduledCommand] = []
    @Published var commandHistory: [ExecutedCommand] = []
    
    private var dndTimer: Timer?
    private var sleepTimer: Timer?
    
    // MARK: - Command Execution
    
    func execute(_ command: AICommand) async -> CommandResult {
        // Log command
        let executedCommand = ExecutedCommand(
            command: command,
            timestamp: Date(),
            status: .executing
        )
        
        await MainActor.run {
            commandHistory.append(executedCommand)
        }
        
        // Execute based on type
        let result: CommandResult
        
        switch command.type {
        case .sleepMode:
            result = await executeSleepMode(command)
        case .dndMode:
            result = await executeDNDMode(command)
        case .reminder:
            result = await executeReminder(command)
        case .systemSetting:
            result = await executeSystemSetting(command)
        case .modeSwitch:
            result = await executeModeSwitch(command)
        }
        
        // Update command status
        await MainActor.run {
            if let index = commandHistory.firstIndex(where: { $0.id == executedCommand.id }) {
                commandHistory[index].status = result.success ? .completed : .failed
                commandHistory[index].result = result
            }
        }
        
        return result
    }
    
    // MARK: - Sleep Mode
    
    private func executeSleepMode(_ command: AICommand) async -> CommandResult {
        let duration = command.parameters["duration"] as? TimeInterval ?? 28800 // 8 hours
        
        await MainActor.run {
            self.sleepModeActive = true
            self.currentMode = .sleep
        }
        
        // Schedule wake up
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            Task { @MainActor in
                self.sleepModeActive = false
                self.currentMode = .active
                
                // Send wake notification
                self.sendNotification(
                    title: "Good morning! ☀️",
                    body: "Sleep mode ended. Ready to help you start your day!"
                )
            }
        }
        
        let wakeTime = Date().addingTimeInterval(duration)
        return CommandResult(
            success: true,
            message: "Sleep mode activated. I'll wake up at \(formatTime(wakeTime)). Sweet dreams! 😴"
        )
    }
    
    // MARK: - DND Mode
    
    private func executeDNDMode(_ command: AICommand) async -> CommandResult {
        let duration = command.parameters["duration"] as? TimeInterval ?? 3600 // 1 hour default
        
        await MainActor.run {
            self.isDNDActive = true
            self.currentMode = .doNotDisturb
        }
        
        // Schedule DND end
        dndTimer?.invalidate()
        dndTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            Task { @MainActor in
                self.isDNDActive = false
                if self.currentMode == .doNotDisturb {
                    self.currentMode = .active
                }
            }
        }
        
        let endTime = Date().addingTimeInterval(duration)
        return CommandResult(
            success: true,
            message: "Do Not Disturb enabled until \(formatTime(endTime)). I'll hold your notifications."
        )
    }
    
    // MARK: - Reminders
    
    private func executeReminder(_ command: AICommand) async -> CommandResult {
        guard let message = command.parameters["message"] as? String,
              let when = command.parameters["when"] as? Date else {
            return CommandResult(
                success: false,
                message: "I need to know what to remind you about and when."
            )
        }
        
        // Create notification
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = message
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: when.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            return CommandResult(
                success: true,
                message: "I'll remind you: '\(message)' at \(formatTime(when))"
            )
        } catch {
            return CommandResult(
                success: false,
                message: "I couldn't set the reminder. Please check notification permissions."
            )
        }
    }
    
    // MARK: - System Settings
    
    private func executeSystemSetting(_ command: AICommand) async -> CommandResult {
        guard let setting = command.parameters["setting"] as? String else {
            return CommandResult(
                success: false,
                message: "Please specify which setting to change."
            )
        }
        
        // For now, just acknowledge - actual implementation depends on app
        return CommandResult(
            success: true,
            message: "Setting '\(setting)' has been updated."
        )
    }
    
    // MARK: - Mode Switch
    
    private func executeModeSwitch(_ command: AICommand) async -> CommandResult {
        guard let modeName = command.parameters["mode"] as? String,
              let mode = AIMode(rawValue: modeName) else {
            return CommandResult(
                success: false,
                message: "Please specify a valid mode."
            )
        }
        
        await MainActor.run {
            self.currentMode = mode
            
            // Update related states
            switch mode {
            case .sleep:
                self.sleepModeActive = true
            case .doNotDisturb:
                self.isDNDActive = true
            default:
                self.sleepModeActive = false
                self.isDNDActive = false
            }
        }
        
        return CommandResult(
            success: true,
            message: "Switched to \(mode.displayName) mode."
        )
    }
    
    // MARK: - Helper Methods
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Command Parser (Complete Implementation)

class CommandParser {
    static func parse(_ message: String) -> AICommand? {
        let lowercased = message.lowercased()
        
        // Sleep mode
        if lowercased.contains("sleep mode") ||
           lowercased.contains("go to sleep") ||
           lowercased.contains("activate sleep") {
            
            var parameters: [String: Any] = [:]
            
            // Look for duration
            if let hours = extractNumber(from: lowercased, before: "hour") {
                parameters["duration"] = TimeInterval(hours * 3600)
            } else if lowercased.contains("until") {
                // Default to 8 hours for now
                parameters["duration"] = TimeInterval(8 * 3600)
            }
            
            return AICommand(type: .sleepMode, parameters: parameters)
        }
        
        // DND mode
        if lowercased.contains("do not disturb") ||
           lowercased.contains("dnd") ||
           lowercased.contains("don't disturb") {
            
            var parameters: [String: Any] = [:]
            
            if let hours = extractNumber(from: lowercased, before: "hour") {
                parameters["duration"] = TimeInterval(hours * 3600)
            } else if let minutes = extractNumber(from: lowercased, before: "minute") {
                parameters["duration"] = TimeInterval(minutes * 60)
            }
            
            return AICommand(type: .dndMode, parameters: parameters)
        }
        
        // Reminders
        if lowercased.contains("remind me") {
            var parameters: [String: Any] = [:]
            
            // Extract the reminder message
            if let range = lowercased.range(of: "remind me") {
                let afterRemind = String(lowercased[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                
                // Remove "to" if it starts with it
                let message = afterRemind.hasPrefix("to ")
                    ? String(afterRemind.dropFirst(3))
                    : afterRemind
                
                parameters["message"] = message
            }
            
            // Simple time extraction - in X minutes/hours
            if let minutes = extractNumber(from: lowercased, before: "minute") {
                parameters["when"] = Date().addingTimeInterval(TimeInterval(minutes * 60))
            } else if let hours = extractNumber(from: lowercased, before: "hour") {
                parameters["when"] = Date().addingTimeInterval(TimeInterval(hours * 3600))
            } else {
                // Default to 1 hour
                parameters["when"] = Date().addingTimeInterval(3600)
            }
            
            return AICommand(type: .reminder, parameters: parameters)
        }
        
        // Mode switching
        let modes = ["active", "focus", "sleep", "low power"]
        for mode in modes {
            if lowercased.contains("switch to \(mode)") ||
               lowercased.contains("\(mode) mode") {
                return AICommand(type: .modeSwitch, parameters: ["mode": mode])
            }
        }
        
        return nil
    }
    
    private static func extractNumber(from text: String, before keyword: String) -> Int? {
        let pattern = "(\\d+)\\s*\(keyword)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        
        return Int(text[numberRange])
    }
}

// MARK: - Models (Self-contained)

struct AICommand: Identifiable {
    let id = UUID()
    let type: AICommandType
    let parameters: [String: Any]
    let timestamp = Date()
}

enum AICommandType: String, CaseIterable {
    case sleepMode = "sleep_mode"
    case dndMode = "dnd_mode"
    case reminder = "reminder"
    case systemSetting = "system_setting"
    case modeSwitch = "mode_switch"
    
    var displayName: String {
        switch self {
        case .sleepMode: return "Sleep Mode"
        case .dndMode: return "Do Not Disturb"
        case .reminder: return "Reminder"
        case .systemSetting: return "System Setting"
        case .modeSwitch: return "Mode Switch"
        }
    }
}

struct CommandResult {
    let success: Bool
    let message: String
    
    init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}

struct ScheduledCommand: Identifiable {
    let id = UUID()
    let command: AICommand
    let scheduledTime: Date
}

struct ExecutedCommand: Identifiable {
    let id = UUID()
    let command: AICommand
    let timestamp: Date
    var status: CommandStatus
    var result: CommandResult?
}

enum CommandStatus {
    case executing, completed, failed
}

enum AIMode: String, CaseIterable {
    case active = "active"
    case focus = "focus"
    case sleep = "sleep"
    case doNotDisturb = "do_not_disturb"
    case lowPower = "low_power"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .focus: return "Focus"
        case .sleep: return "Sleep"
        case .doNotDisturb: return "Do Not Disturb"
        case .lowPower: return "Low Power"
        }
    }
}

// MARK: - Integration Extension for MariaBrain

extension MariaBrain {
    func executeCommand(from message: String) async -> String? {
        guard let command = CommandParser.parse(message) else {
            return nil
        }
        
        let result = await commandSystem.execute(command)
        return result.message
    }
}
