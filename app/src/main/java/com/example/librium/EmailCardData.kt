package com.example.librium

// Simple data class for emails
data class EmailCardData(
    val id: String = java.util.UUID.randomUUID().toString(),
    val subject: String,
    val sender: String,
    val senderEmail: String? = null,
    val preview: String,
    val timestamp: Long,
    val isUnread: Boolean = true,
    val hasAttachment: Boolean = false,
    val isImportant: Boolean = false,
    val labels: List<String> = emptyList()
)