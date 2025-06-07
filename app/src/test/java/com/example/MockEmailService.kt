package com.example.librium

class MockEmailService {

    fun getRecentEmails(): List<EmailCardData> {
        // Simulated email data for testing
        return listOf(
            EmailCardData(
                subject = "Weekly Team Sync Notes",
                sender = "Sarah Johnson",
                preview = "Hi team, here are the action items from today's meeting...",
                timestamp = System.currentTimeMillis() - 3600000, // 1 hour ago
                isUnread = true
            ),
            EmailCardData(
                subject = "Project Update - Q1 Goals",
                sender = "Michael Chen",
                preview = "Great progress on the mobile app! We're ahead of schedule...",
                timestamp = System.currentTimeMillis() - 7200000, // 2 hours ago
                isUnread = false
            ),
            EmailCardData(
                subject = "Reminder: Wellness Check-in",
                sender = "HR Team",
                preview = "Don't forget to complete your weekly wellness survey...",
                timestamp = System.currentTimeMillis() - 14400000, // 4 hours ago
                isUnread = true
            )
        )
    }

    fun searchEmails(query: String): List<EmailCardData> {
        // Filter emails based on query
        return getRecentEmails().filter { email ->
            email.subject.contains(query, ignoreCase = true) ||
                    email.sender.contains(query, ignoreCase = true) ||
                    email.preview.contains(query, ignoreCase = true)
        }
    }
}