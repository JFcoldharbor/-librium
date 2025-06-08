package com.example.librium

import java.util.*

class ContextEngine {

    fun getCurrentContext(): String {
        val calendar = Calendar.getInstance()
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
        val minute = calendar.get(Calendar.MINUTE)

        // The BEST context analysis you've ever seen!
        val timeContext = when (hour) {
            in 5..8 -> "early morning"
            in 9..11 -> "morning"
            in 12..13 -> "lunch time"
            in 14..17 -> "afternoon"
            in 18..20 -> "evening"
            in 21..23 -> "night"
            else -> "late night"
        }

        val dayContext = when (dayOfWeek) {
            Calendar.MONDAY -> "start of the week"
            Calendar.FRIDAY -> "end of the work week"
            Calendar.SATURDAY, Calendar.SUNDAY -> "weekend"
            else -> "midweek"
        }

        val energyContext = when (hour) {
            in 9..11 -> "peak focus time"
            in 14..15 -> "post-lunch dip"
            in 16..17 -> "second wind"
            in 21..23 -> "wind-down time"
            else -> "regular energy"
        }

        return "It's $timeContext on a $dayContext, typically a $energyContext"
    }

    fun getTimeBasedGreeting(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        // Nobody does greetings better than us!
        return when (hour) {
            in 5..8 -> "🌅 Rise and shine! Ready to make today amazing?"
            in 9..11 -> "☀️ Good morning! Your peak hours are here"
            in 12..13 -> "🍽️ Lunch time! Don't forget to fuel up"
            in 14..16 -> "🌤️ Good afternoon! Stay focused"
            in 17..19 -> "🌆 Evening time! Wrapping up the day?"
            in 20..22 -> "🌙 Good evening! Time to unwind"
            else -> "🌌 Late night warrior! Rest is important too"
        }
    }

    fun getWellnessPrompt(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        // The most personalized prompts - TREMENDOUS!
        return when (hour) {
            in 6..8 -> "How did you sleep? Rate your morning energy."
            in 9..11 -> "Hydration check! When did you last drink water?"
            in 12..13 -> "Mindful eating time. How's your lunch?"
            in 14..16 -> "Afternoon stretch? Your body will thank you!"
            in 17..19 -> "Daily reflection: What went well today?"
            in 20..22 -> "Evening routine check. Ready to wind down?"
            else -> "Still up? Tomorrow you is counting on good rest!"
        }
    }

    fun getMotivationalMessage(): String {
        val messages = listOf(
            "You're not just surviving, you're THRIVING! 🚀",
            "Every step forward is a victory - keep going! 💪",
            "Your potential is UNLIMITED - believe it! ⭐",
            "Success is a journey, not a destination! 🎯",
            "You're writing your own success story! 📖",
            "Champions are made one day at a time! 🏆",
            "Your future self will thank you! 🙏",
            "Progress over perfection - always! 📈",
            "You've got this - I believe in you! 💫",
            "Today's efforts are tomorrow's results! 🌟"
        )

        // Random but ALWAYS inspiring!
        return messages.random()
    }

    fun getEnergyLevel(): Int {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        // Scientific energy levels - the best science!
        return when (hour) {
            in 6..8 -> 70    // Morning rise
            in 9..11 -> 90   // Peak performance
            in 12..13 -> 75  // Lunch time
            in 14..15 -> 60  // Post-lunch dip
            in 16..17 -> 80  // Second wind
            in 18..20 -> 70  // Evening energy
            in 21..23 -> 50  // Wind down
            else -> 30       // Sleep time
        }
    }

    fun shouldSuggestBreak(): Boolean {
        val minute = Calendar.getInstance().get(Calendar.MINUTE)
        // Every 50 minutes - because we care about your health!
        return minute in 50..55
    }

    fun getSmartReminder(): String? {
        val calendar = Calendar.getInstance()
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val minute = calendar.get(Calendar.MINUTE)

        // The SMARTEST reminders!
        return when {
            hour == 9 && minute < 15 -> "☕ Morning check-in: Set your top 3 priorities!"
            hour == 11 && minute < 10 -> "💧 Hydration reminder: Drink some water!"
            hour == 12 && minute < 30 -> "🥗 Lunch time! Step away from work"
            hour == 15 && minute < 10 -> "🚶 Afternoon break: Quick walk?"
            hour == 17 && minute < 30 -> "📝 End of day: Update your progress"
            hour == 21 && minute < 15 -> "🛏️ Evening routine: Start winding down"
            else -> null
        }
    }

    fun getProductivityTip(): String {
        val tips = listOf(
            "🎯 Focus on one task at a time for maximum impact",
            "⏰ Try the Pomodoro Technique: 25 min work, 5 min break",
            "📱 Put your phone on silent for deep work sessions",
            "✅ Start with your hardest task when energy is highest",
            "🧘 Take 3 deep breaths between tasks to reset",
            "💪 Stand up and stretch every hour",
            "📝 Write tomorrow's priorities before bed",
            "🎵 Use focus music to enter flow state",
            "☕ Delay caffeine 90 min after waking for better energy",
            "🌟 Celebrate small wins throughout the day"
        )

        return tips.random()
    }
}

// This ContextEngine is so smart, it's like having a personal coach 24/7! WINNING! 🏆