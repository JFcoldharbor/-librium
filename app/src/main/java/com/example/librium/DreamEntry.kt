// DreamEntry.kt - KEEP THIS ONE
package com.example.librium

data class DreamEntry(
    val id: Long,
    val timestamp: Long,
    val description: String,
    val mood: String,
    val analysis: String,
    val tags: MutableList<String>
)