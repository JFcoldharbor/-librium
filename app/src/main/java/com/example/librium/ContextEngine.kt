package com.example.librium

import java.text.SimpleDateFormat
import java.util.*

class ContextEngine {

    fun getCurrentContext(): Map<String, Any> {
        val calendar = Calendar.getInstance()
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
        val minute = calendar.get(Calendar.MINUTE)

        return mapOf(
            "timeOfDay" to getTimeOfDay(hour),
            "exactTime" to String.format("%02d:%02d", hour, minute),
            "dayOfWeek" to getDayName(dayOfWeek),
            "dayType" to getDayType(dayOfWeek),
            "hour" to hour,
            "isWorkingHours" to isWorkingHours(hour, dayOfWeek),
            "mealTime" to (getMealTime(hour) ?: "none"),
            "energyLevel" to getEnergyLevel(hour),
            "focusTime" to isFocusTime(hour),
            "date" to SimpleDateFormat("MMMM d, yyyy", Locale.getDefault()).format(Date())
        )
    }

    fun getTimeOfDay(hour: Int): String {
        return when (hour) {
            in 5..11 -> "morning"
            in 12..16 -> "afternoon"
            in 17..20 -> "evening"
            else -> "night"
        }
    }

    fun getDayName(dayOfWeek: Int): String {
        return when (dayOfWeek) {
            Calendar.SUNDAY -> "Sunday"
            Calendar.MONDAY -> "Monday"
            Calendar.TUESDAY -> "Tuesday"
            Calendar.WEDNESDAY -> "Wednesday"
            Calendar.THURSDAY -> "Thursday"
            Calendar.FRIDAY -> "Friday"
            Calendar.SATURDAY -> "Saturday"
            else -> "Unknown"
        }
    }

    fun getDayType(dayOfWeek: Int): String {
        return when (dayOfWeek) {
            Calendar.SATURDAY, Calendar.SUNDAY -> "weekend"
            else -> "weekday"
        }
    }

    fun isWorkingHours(hour: Int, dayOfWeek: Int): Boolean {
        val isWeekday = dayOfWeek !in listOf(Calendar.SATURDAY, Calendar.SUNDAY)
        return isWeekday && hour in 9..17
    }

    fun getMealTime(hour: Int): String? {
        return when (hour) {
            in 6..9 -> "breakfast"
            in 11..13 -> "lunch"
            in 17..20 -> "dinner"
            in 14..16 -> "snack"
            else -> null
        }
    }

    fun getEnergyLevel(hour: Int): String {
        return when (hour) {
            in 6..9 -> "building" // Morning energy building
            in 10..11 -> "peak" // Morning peak
            in 13..14 -> "low" // Post-lunch dip
            in 15..17 -> "moderate" // Afternoon recovery
            in 18..20 -> "winding_down" // Evening decline
            else -> "resting" // Night time
        }
    }

    fun isFocusTime(hour: Int): Boolean {
        // Best focus times: late morning and mid-afternoon
        return hour in listOf(10, 11, 15, 16)
    }

    fun getTimeBasedGreeting(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when (hour) {
            in 5..11 -> "Good morning! ☀️"
            in 12..16 -> "Good afternoon! 🌤️"
            in 17..20 -> "Good evening! 🌅"
            else -> "Good night! 🌙"
        }
    }

    fun getWellnessPrompt(): String {
        val context = getCurrentContext()
        val hour = context["hour"] as Int
        val dayType = context["dayType"] as String
        val mealTime = context["mealTime"] as? String
        val energyLevel = context["energyLevel"] as String

        return when {
            // Morning wellness
            hour in 6..8 -> "Start your day right! Have you had water yet? 💧"

            // Breakfast reminder
            hour == 9 && mealTime == "breakfast" -> "Don't skip breakfast! Fuel your body for the day ahead. 🥑"

            // Mid-morning productivity
            hour in 10..11 -> "Peak focus time! This is when your brain works best. 🧠"

            // Lunch break
            hour == 12 -> "Time for a lunch break! Step away from your screen. 🥗"

            // Afternoon slump
            hour in 13..14 -> "Feeling the afternoon slump? A short walk can boost your energy! 🚶"

            // Hydration reminder
            hour == 15 -> "Afternoon hydration check! Aim for another glass of water. 💧"

            // Evening wind down
            hour in 18..19 -> "Evening is here. Time to start winding down. 🌅"

            // Sleep prep
            hour >= 21 -> "Consider winding down for better sleep. Blue light filters on? 😴"

            // Weekend special
            dayType == "weekend" && hour in 9..11 -> "It's the weekend! Perfect time for that workout you've been planning. 💪"

            else -> "How can I support your wellness journey today? 🌟"
        }
    }

    fun getActivitySuggestion(): String {
        val context = getCurrentContext()
        val hour = context["hour"] as Int
        val dayType = context["dayType"] as String
        val energyLevel = context["energyLevel"] as String

        return when {
            // Morning exercise
            hour in 6..7 -> "Perfect time for morning exercise! Even 20 minutes makes a difference."

            // Morning walk
            hour in 8..9 && dayType == "weekday" -> "Quick walk before work? It'll boost your productivity!"

            // Focus work
            energyLevel == "peak" -> "Your energy is peaking! Tackle your most important task now."

            // Afternoon break
            hour in 14..15 -> "Take a 5-minute movement break. Your body will thank you!"

            // Evening activity
            hour in 17..18 -> "Great time for a gym session or home workout!"

            // Weekend morning
            dayType == "weekend" && hour in 8..10 -> "Weekend yoga or a nature walk? Perfect timing!"

            // Night routine
            hour >= 21 -> "Time for relaxation. Try some light stretching or meditation."

            else -> "Stay active! Every movement counts toward your wellness goals."
        }
    }

    fun getMotivationalQuote(): String {
        val quotes = listOf(
            "Small steps daily lead to big changes yearly! 👣",
            "Your health is an investment, not an expense! 💎",
            "Progress, not perfection. You've got this! 💪",
            "Every healthy choice is a victory! 🏆",
            "Your future self will thank you! 🌟",
            "Wellness is a journey, not a destination! 🛤️",
            "You're stronger than you think! 💪",
            "Today's actions are tomorrow's results! 📈"
        )

        // Select quote based on time to provide variety
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val index = hour % quotes.size
        return quotes[index]
    }

    fun getHealthTip(): String {
        val context = getCurrentContext()
        val hour = context["hour"] as Int
        val mealTime = context["mealTime"] as? String

        val tips = when {
            hour in 6..8 -> listOf(
                "Start with a glass of warm water with lemon 🍋",
                "Morning sunlight helps regulate your circadian rhythm ☀️",
                "5 minutes of stretching prevents all-day stiffness 🧘"
            )

            mealTime == "lunch" -> listOf(
                "Eat slowly and mindfully for better digestion 🥗",
                "Include protein to avoid afternoon energy crashes 🥙",
                "Take a short walk after lunch for better focus 🚶"
            )

            hour in 14..16 -> listOf(
                "Afternoon slump? Try deep breathing instead of coffee 🌬️",
                "20-20-20 rule: Every 20 mins, look at something 20 feet away 👀",
                "Healthy snacks: nuts, fruits, or yogurt 🥜"
            )

            hour >= 20 -> listOf(
                "Dim the lights to prepare your body for sleep 🌙",
                "No screens 30 minutes before bed for better sleep 📵",
                "Gratitude journaling improves sleep quality 📝"
            )

            else -> listOf(
                "Stand up and move every hour 🚶",
                "Deep breathing reduces stress instantly 🌬️",
                "Hydration is key to energy and focus 💧"
            )
        }

        return tips.random()
    }
}