package com.example.librium

import java.util.UUID

// Message Types
enum class MessageType {
    TEXT,                // Regular text message
    WELLNESS_CARD,       // Health stats card
    EMAIL_CARD,          // Email preview card
    CALENDAR_CARD,       // Schedule/meeting card
    REMINDER_CARD,       // Reminder/task card
    SUGGESTION_CARD,     // AI suggestion card
    ERROR_MESSAGE,       // Error display
    LOADING             // Loading indicator
}

// Main Chat Message
data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val text: String,
    val isFromUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val messageType: MessageType = MessageType.TEXT,
    val cardData: Any? = null,
    val isRead: Boolean = false
)

// Wellness Card Data
data class WellnessCardData(
    val steps: Int,
    val stepGoal: Int = 10000,
    val calories: Int,
    val calorieGoal: Int = 2000,
    val heartRate: Int,
    val heartRateStatus: String = "Normal",
    val water: Int = 0,
    val waterGoal: Int = 8,
    val sleepHours: Float? = null,
    val mood: String? = null,
    val lastUpdated: Long = System.currentTimeMillis()
) {
    fun getStepProgress(): Float = (steps.toFloat() / stepGoal) * 100
    fun getCalorieProgress(): Float = (calories.toFloat() / calorieGoal) * 100
    fun getWaterProgress(): Float = (water.toFloat() / waterGoal) * 100
}

// Email Card Data - COMMENTED OUT (not using email feature yet)
// data class EmailCardData(
//     val id: String = UUID.randomUUID().toString(),
//     val subject: String,
//     val sender: String,
//     val senderEmail: String? = null,
//     val preview: String,
//     val timestamp: Long,
//     val isUnread: Boolean = true,
//     val hasAttachment: Boolean = false,
//     val isImportant: Boolean = false,
//     val labels: List<String> = emptyList()
// )

// Calendar Card Data
data class CalendarCardData(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val startTime: Long,
    val endTime: Long,
    val location: String? = null,
    val attendees: List<String> = emptyList(),
    val isAllDay: Boolean = false,
    val reminderMinutes: Int = 15,
    val meetingLink: String? = null,
    val status: MeetingStatus = MeetingStatus.UPCOMING
)

enum class MeetingStatus {
    UPCOMING,
    IN_PROGRESS,
    COMPLETED,
    CANCELLED
}

// Reminder Card Data
data class ReminderCardData(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val description: String? = null,
    val dueTime: Long? = null,
    val priority: Priority = Priority.MEDIUM,
    val isCompleted: Boolean = false,
    val category: String? = null
)

enum class Priority {
    LOW,
    MEDIUM,
    HIGH,
    URGENT
}

// Suggestion Card Data
data class SuggestionCardData(
    val title: String,
    val description: String,
    val actionText: String,
    val actionType: SuggestionAction,
    val iconType: String? = null,
    val metadata: Map<String, Any> = emptyMap()
)

enum class SuggestionAction {
    OPEN_WELLNESS,
    SCHEDULE_REMINDER,
    START_EXERCISE,
    CHECK_EMAILS,
    VIEW_CALENDAR,
    MEDITATION,
    HYDRATION_REMINDER,
    CUSTOM
}

// User Profile (for context)
data class UserProfile(
    val name: String = "User",
    val preferences: UserPreferences = UserPreferences(),
    val goals: WellnessGoals = WellnessGoals()
)

data class UserPreferences(
    val preferredWorkoutTime: String = "morning",
    val notificationEnabled: Boolean = true,
    val theme: String = "dark",
    val language: String = "en",
    val units: String = "metric" // or "imperial"
)

data class WellnessGoals(
    val dailySteps: Int = 10000,
    val dailyCalories: Int = 2000,
    val weeklyExerciseDays: Int = 5,
    val dailyWaterGlasses: Int = 8,
    val sleepHours: Int = 8,
    val focusHours: Int = 4
)

// Conversation Context
data class ConversationContext(
    val messages: MutableList<ChatMessage> = mutableListOf(),
    val lastTopics: MutableList<String> = mutableListOf(),
    val userMood: String? = null,
    val lastInteractionTime: Long = System.currentTimeMillis()
) {
    fun addMessage(message: ChatMessage) {
        messages.add(message)
        if (messages.size > 100) {
            // Keep only last 100 messages to prevent memory issues
            messages.removeAt(0)
        }
    }

    fun getRecentMessages(count: Int = 5): List<ChatMessage> {
        return messages.takeLast(count)
    }
}

// Response Templates (for consistent formatting)
object ResponseTemplates {
    fun wellnessCardTemplate(data: WellnessCardData): String = """
╔══════════════════════════════════╗
║      💪 WELLNESS UPDATE          ║
╠══════════════════════════════════╣
║  👟 Steps:     ${data.steps} / ${data.stepGoal}
║  🔥 Calories:  ${data.calories} cal
║  ❤️ Heart Rate: ${data.heartRate} bpm
║  💧 Water:     ${data.water} / ${data.waterGoal} glasses
╚══════════════════════════════════╝
    """.trimIndent()

    fun emailCardTemplate(email: EmailCardData): String = """
┌─────────────────────────────────┐
│ ${if (email.isUnread) "● " else "  "}${email.subject}
│ From: ${email.sender}
│ 📎 ${if (email.hasAttachment) "Has attachment" else "No attachment"}
│ "${email.preview.take(50)}..."
└─────────────────────────────────┘
    """.trimIndent()

    fun scheduleCardTemplate(event: CalendarCardData): String = """
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ 📅 ${event.title}
┃ 🕐 ${formatTime(event.startTime)} - ${formatTime(event.endTime)}
┃ 📍 ${event.location ?: "No location"}
┃ 👥 ${event.attendees.size} attendees
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    """.trimIndent()

    private fun formatTime(timestamp: Long): String {
        val sdf = java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault())
        return sdf.format(java.util.Date(timestamp))
    }
}