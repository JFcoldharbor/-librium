package com.example.librium

import java.text.SimpleDateFormat
import java.util.*

class ContextEngine {

    fun getCurrentContext(): Map<String, Any> {
        val calendar = Calendar.getInstance()
        val currentTime = calendar.time

        val context = mutableMapOf<String, Any>()

        // Time context
        context["time"] = SimpleDateFormat("HH:mm", Locale.getDefault()).format(currentTime)
        context["hour"] = calendar.get(Calendar.HOUR_OF_DAY)
        context["dayOfWeek"] = getDayOfWeek(calendar.get(Calendar.DAY_OF_WEEK))
        context["date"] = SimpleDateFormat("MMMM d, yyyy", Locale.getDefault()).format(currentTime)
        context["timeOfDay"] = getTimeOfDay(calendar.get(Calendar.HOUR_OF_DAY))

        // User state context (can be expanded with real data later)
        context["userState"] = getUserState(calendar.get(Calendar.HOUR_OF_DAY))

        // Wellness context (placeholder - can integrate with real data)
        context["lastActivityTime"] = "2 hours ago"
        context["hydrationReminder"] = shouldRemindHydration(calendar.get(Calendar.HOUR_OF_DAY))

        return context
    }

    private fun getDayOfWeek(day: Int): String {
        return when (day) {
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

    private fun getTimeOfDay(hour: Int): String {
        return when (hour) {
            in 5..11 -> "morning"
            in 12..16 -> "afternoon"
            in 17..20 -> "evening"
            else -> "night"
        }
    }

    private fun getUserState(hour: Int): String {
        return when (hour) {
            in 6..8 -> "waking_up"
            in 9..11 -> "morning_routine"
            in 12..13 -> "lunch_time"
            in 14..17 -> "afternoon_work"
            in 18..20 -> "evening_routine"
            in 21..23 -> "winding_down"
            else -> "sleeping"
        }
    }

    private fun shouldRemindHydration(hour: Int): Boolean {
        // Remind every 2 hours during waking hours
        return hour in 8..20 && hour % 2 == 0
    }

    fun getContextualGreeting(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when (hour) {
            in 5..11 -> "Good morning"
            in 12..16 -> "Good afternoon"
            in 17..20 -> "Good evening"
            else -> "Hello"
        }
    }

    fun getWellnessPrompt(): String {
        val context = getCurrentContext()
        val timeOfDay = context["timeOfDay"] as String
        val userState = context["userState"] as String

        return when (userState) {
            "waking_up" -> "How did you sleep? Ready to start your day with some stretches?"
            "morning_routine" -> "Have you had your morning water and breakfast?"
            "lunch_time" -> "Time for a healthy lunch break. Remember to step away from your screen!"
            "afternoon_work" -> "How's your energy level? Maybe time for a quick walk?"
            "evening_routine" -> "How was your day? Ready to wind down?"
            "winding_down" -> "Time to relax. How about some meditation or light reading?"
            else -> "How are you feeling right now?"
        }
    }
}