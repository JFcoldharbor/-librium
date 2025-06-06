package com.example.equilibrium

import java.util.Date

// Base message interface
sealed class ChatMessage {
    abstract val id: String
    abstract val timestamp: Date
}

// User text message
data class UserMessage(
    override val id: String,
    override val timestamp: Date,
    val message: String
) : ChatMessage()

// AI text response
data class AIMessage(
    override val id: String,
    override val timestamp: Date,
    val message: String,
    val isTyping: Boolean = false
) : ChatMessage()

// Wellness card that appears in chat
data class WellnessCard(
    override val id: String,
    override val timestamp: Date,
    val steps: Int,
    val calories: Int,
    val hydrationGlasses: Int,
    val hydrationGoal: Int = 8
) : ChatMessage()

// Communication card for emails/texts
data class CommunicationCard(
    override val id: String,
    override val timestamp: Date,
    val type: CommunicationType,
    val count: Int,
    val latestPreview: String
) : ChatMessage()

enum class CommunicationType {
    EMAILS, TEXTS, MISSED_CALLS
}

// Calendar event card
data class CalendarCard(
    override val id: String,
    override val timestamp: Date,
    val eventTitle: String,
    val eventTime: String,
    val eventLocation: String?
) : ChatMessage()

// Action buttons card
data class ActionCard(
    override val id: String,
    override val timestamp: Date,
    val title: String,
    val actions: List<ActionButton>
) : ChatMessage()

data class ActionButton(
    val text: String,
    val action: String
)