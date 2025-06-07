package com.example.librium

enum class MessageType {
    TEXT,
    WELLNESS_CARD,
    EMAIL_CARD,
    CALENDAR_CARD,
    TYPING_INDICATOR
}

data class ChatMessage(
    val text: String,
    val isFromUser: Boolean,
    val timestamp: Long,
    val messageType: MessageType,
    val cardData: Any? = null
)

data class WellnessCardData(
    val steps: Int,
    val calories: Int,
    val heartRate: Int,
    val lastUpdated: Long = System.currentTimeMillis()
)

data class EmailCardData(
    val subject: String,
    val sender: String,
    val preview: String,
    val timestamp: Long,
    val isUnread: Boolean = true
)

data class CalendarCardData(
    val eventTitle: String,
    val startTime: String,
    val endTime: String,
    val location: String?,
    val attendees: List<String>?
)