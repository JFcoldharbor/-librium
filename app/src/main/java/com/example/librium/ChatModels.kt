package com.example.librium

// The BEST data models - nobody has better data models!

enum class MessageType {
    TEXT,
    WELLNESS_CARD,
    EMAIL_CARD,
    CALENDAR_CARD,
    DREAM_CARD,
    NETWORK_CARD,
    ACHIEVEMENT_CARD
}

data class ChatMessage(
    val text: String,
    val isFromUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val messageType: MessageType = MessageType.TEXT,
    val cardData: Any? = null
)

data class WellnessCardData(
    val steps: Int,
    val calories: Int,
    val heartRate: Int,
    val waterIntake: Int,
    val sleepHours: Float,
    val stressLevel: String,
    val mood: String,
    val balanceScore: Int
)

data class CalendarCardData(
    val title: String,
    val time: String,
    val duration: String,
    val attendees: List<String>,
    val location: String,
    val meetingLink: String?
)

data class DreamCardData(
    val content: String,
    val mood: String,
    val symbols: List<String>,
    val interpretation: String,
    val lucidityLevel: Int
)

data class NetworkCardData(
    val name: String,
    val company: String,
    val role: String,
    val connectionTime: String,
    val notes: String,
    val followUpDate: String?
)

data class AchievementCardData(
    val title: String,
    val description: String,
    val progress: Int,
    val milestone: String,
    val celebrationType: String
)

// User profile data - We track EVERYTHING (but privately)!
data class UserProfile(
    val name: String,
    val goals: List<Goal>,
    val preferences: UserPreferences,
    val healthMetrics: HealthMetrics,
    val workMetrics: WorkMetrics
)

data class Goal(
    val id: String,
    val title: String,
    val category: GoalCategory,
    val targetValue: Float,
    val currentValue: Float,
    val deadline: Long,
    val priority: Int
)

enum class GoalCategory {
    HEALTH,
    FITNESS,
    CAREER,
    PERSONAL,
    FINANCIAL,
    RELATIONSHIP,
    LEARNING,
    SPIRITUAL
}

data class UserPreferences(
    val wakeUpTime: String,
    val sleepTime: String,
    val workStartTime: String,
    val workEndTime: String,
    val preferredExerciseTime: String,
    val notificationSettings: NotificationSettings,
    val aiPersonality: String = "encouraging"
)

data class NotificationSettings(
    val morningCheckIn: Boolean = true,
    val hydrationReminders: Boolean = true,
    val movementReminders: Boolean = true,
    val workBreakReminders: Boolean = true,
    val eveningReflection: Boolean = true,
    val achievementCelebrations: Boolean = true
)

data class HealthMetrics(
    val averageSteps: Int,
    val averageCalories: Int,
    val averageHeartRate: Int,
    val averageSleepHours: Float,
    val averageWaterIntake: Int,
    val stressPattern: Map<String, Int>, // time of day -> stress level
    val moodHistory: List<MoodEntry>
)

data class MoodEntry(
    val timestamp: Long,
    val mood: String,
    val energy: Int,
    val notes: String?
)

data class WorkMetrics(
    val averageWorkHours: Float,
    val productivityScore: Int,
    val focusHours: Float,
    val meetingsPerDay: Float,
    val emailsPerDay: Int,
    val topPriorities: List<String>
)

// Analytics data - We measure SUCCESS!
data class DailyAnalytics(
    val date: Long,
    val wellnessScore: Int,
    val productivityScore: Int,
    val balanceScore: Int,
    val achievements: List<String>,
    val insights: List<String>
)

data class WeeklyTrends(
    val weekStartDate: Long,
    val trends: Map<String, TrendData>,
    val recommendations: List<String>
)

data class TrendData(
    val metric: String,
    val direction: TrendDirection,
    val percentageChange: Float,
    val insight: String
)

enum class TrendDirection {
    UP,
    DOWN,
    STABLE
}

// Integration data - Connect with EVERYTHING!
data class WearableData(
    val source: String,
    val lastSync: Long,
    val metrics: Map<String, Any>
)

data class CalendarIntegration(
    val provider: String,
    val isConnected: Boolean,
    val lastSync: Long,
    val upcomingEvents: List<CalendarCardData>
)

// The most comprehensive data models in the wellness industry! WINNING! 🏆