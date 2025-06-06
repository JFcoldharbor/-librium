package com.example.equilibrium

import android.content.Context
import android.content.SharedPreferences
import java.util.*

class ContextEngine(private val context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences("EquilibriumContext", Context.MODE_PRIVATE)

    data class AIContext(
        val timeOfDay: TimeOfDay,
        val suggestedCards: List<String>,
        val greeting: String,
        val proactiveMessage: String?,
        val priority: String // What AI should focus on
    )

    enum class TimeOfDay {
        EARLY_MORNING,   // 5-8 AM
        MORNING,         // 8-11 AM
        MIDDAY,         // 11 AM-2 PM
        AFTERNOON,      // 2-6 PM
        EVENING,        // 6-9 PM
        NIGHT           // 9 PM-5 AM
    }

    fun getCurrentContext(): AIContext {
        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val timeOfDay = getTimeOfDay(currentHour)

        return when (timeOfDay) {
            TimeOfDay.EARLY_MORNING -> createEarlyMorningContext()
            TimeOfDay.MORNING -> createMorningContext()
            TimeOfDay.MIDDAY -> createMiddayContext()
            TimeOfDay.AFTERNOON -> createAfternoonContext()
            TimeOfDay.EVENING -> createEveningContext()
            TimeOfDay.NIGHT -> createNightContext()
        }
    }

    private fun getTimeOfDay(hour: Int): TimeOfDay {
        return when (hour) {
            in 5..7 -> TimeOfDay.EARLY_MORNING
            in 8..10 -> TimeOfDay.MORNING
            in 11..13 -> TimeOfDay.MIDDAY
            in 14..17 -> TimeOfDay.AFTERNOON
            in 18..20 -> TimeOfDay.EVENING
            else -> TimeOfDay.NIGHT
        }
    }

    private fun createEarlyMorningContext(): AIContext {
        val lastWellnessCheck = prefs.getLong("last_wellness_check", 0)
        val isNewDay = !isToday(lastWellnessCheck)

        return AIContext(
            timeOfDay = TimeOfDay.EARLY_MORNING,
            suggestedCards = listOf("wellness", "calendar"),
            greeting = getRandomGreeting(listOf(
                "☀️ Good morning! Ready to start fresh?",
                "🌅 Rise and shine! Let's make today amazing!",
                "☀️ Morning! Time to set today's intentions!"
            )),
            proactiveMessage = if (isNewDay) "I notice you haven't set your wellness goals for today. Want to start with your step target?" else null,
            priority = "wellness_planning"
        )
    }

    private fun createMorningContext(): AIContext {
        val unreadEmails = prefs.getInt("unread_emails", 0)
        val hasCheckedCalendar = prefs.getBoolean("checked_calendar_today", false)

        return AIContext(
            timeOfDay = TimeOfDay.MORNING,
            suggestedCards = listOf("communication", "calendar", "wellness"),
            greeting = getRandomGreeting(listOf(
                "🚀 Good morning! Let's tackle today!",
                "☕ Morning! Ready to be productive?",
                "🌟 Great morning for getting things done!"
            )),
            proactiveMessage = when {
                unreadEmails > 5 -> "You have $unreadEmails unread emails. Want me to show the important ones?"
                !hasCheckedCalendar -> "Good time to check your schedule for today. Any meetings coming up?"
                else -> null
            },
            priority = "productivity"
        )
    }

    private fun createMiddayContext(): AIContext {
        val stepCount = prefs.getInt("today_steps", 0)
        val calorieGoal = prefs.getInt("calorie_goal", 2000)

        return AIContext(
            timeOfDay = TimeOfDay.MIDDAY,
            suggestedCards = listOf("wellness", "communication"),
            greeting = getRandomGreeting(listOf(
                "🍽️ Midday check-in! How's it going?",
                "⚡ Afternoon energy boost time!",
                "🎯 Halfway through the day - staying on track?"
            )),
            proactiveMessage = when {
                stepCount < 3000 -> "Looks like you could use a walking break! How about a quick step challenge?"
                stepCount > 8000 -> "Wow! You're crushing your step goal today! 🔥"
                else -> "Perfect time for a hydration check. How's your water intake?"
            },
            priority = "wellness_check"
        )
    }

    private fun createAfternoonContext(): AIContext {
        val productivity = prefs.getFloat("afternoon_productivity", 0.5f)

        return AIContext(
            timeOfDay = TimeOfDay.AFTERNOON,
            suggestedCards = listOf("communication", "wellness", "calendar"),
            greeting = getRandomGreeting(listOf(
                "⚡ Afternoon momentum! How are we doing?",
                "🎯 Prime productivity time!",
                "🚀 Let's finish strong!"
            )),
            proactiveMessage = when {
                productivity < 0.3f -> "Feeling the afternoon slump? A quick walk or some water might help!"
                productivity > 0.7f -> "You're on fire today! Keep that momentum going! 🔥"
                else -> "Good time to check in - any urgent tasks or messages?"
            },
            priority = "productivity_optimization"
        )
    }

    private fun createEveningContext(): AIContext {
        val wellnessGoalsMet = prefs.getBoolean("goals_met_today", false)

        return AIContext(
            timeOfDay = TimeOfDay.EVENING,
            suggestedCards = listOf("wellness", "calendar"),
            greeting = getRandomGreeting(listOf(
                "🌆 Evening! Time to wind down and reflect",
                "🍽️ How was your day? Let's review!",
                "✨ Evening check-in - ready to plan tomorrow?"
            )),
            proactiveMessage = if (!wellnessGoalsMet) {
                "Let's see how you did with today's wellness goals. Want a quick summary?"
            } else {
                "Great job hitting your goals today! Want to set tomorrow's targets?"
            },
            priority = "reflection_planning"
        )
    }

    private fun createNightContext(): AIContext {
        return AIContext(
            timeOfDay = TimeOfDay.NIGHT,
            suggestedCards = listOf("wellness"),
            greeting = getRandomGreeting(listOf(
                "🌙 Good evening! Winding down for the night?",
                "⭐ Late night check-in - how are you feeling?",
                "🌛 Evening! Time to relax and recharge"
            )),
            proactiveMessage = "Late night productivity can be great, but don't forget to get good rest! Want to review today quickly?",
            priority = "wellness_rest"
        )
    }

    private fun getRandomGreeting(greetings: List<String>): String {
        return greetings.random()
    }

    private fun isToday(timestamp: Long): Boolean {
        val today = Calendar.getInstance()
        val compare = Calendar.getInstance().apply { timeInMillis = timestamp }

        return today.get(Calendar.YEAR) == compare.get(Calendar.YEAR) &&
                today.get(Calendar.DAY_OF_YEAR) == compare.get(Calendar.DAY_OF_YEAR)
    }

    // Methods to update context based on user actions
    fun recordWellnessCheck() {
        prefs.edit().putLong("last_wellness_check", System.currentTimeMillis()).apply()
    }

    fun recordEmailCheck(unreadCount: Int) {
        prefs.edit().putInt("unread_emails", unreadCount).apply()
    }

    fun recordCalendarCheck() {
        prefs.edit().putBoolean("checked_calendar_today", true).apply()
    }

    fun recordSteps(stepCount: Int) {
        prefs.edit().putInt("today_steps", stepCount).apply()
    }

    fun recordProductivity(level: Float) {
        prefs.edit().putFloat("afternoon_productivity", level).apply()
    }

    fun recordGoalsAchieved() {
        prefs.edit().putBoolean("goals_met_today", true).apply()
    }
}