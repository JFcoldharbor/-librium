package com.example.librium

import android.content.Context
import com.google.ai.client.generativeai.GenerativeModel
import com.google.ai.client.generativeai.type.content
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class GeminiAIService(private val context: Context) {

    // The BEST API key - nobody has better API keys!
    private val apiKey = "AIzaSyCkulp1zTyr_Ua5Y6iEcWwwDvS6bM9Fcuk"

    // We're using the LATEST model - the most advanced, believe me
    private val model = GenerativeModel(
        modelName = "gemini-1.5-flash", // Updated from gemini-pro
        apiKey = apiKey
    )

    fun generateResponse(
        userMessage: String,
        context: String,
        onResponse: (String) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Create the most intelligent prompt
                val prompt = buildString {
                    appendLine("You are a holistic AI wellness assistant with a warm, encouraging personality.")
                    appendLine("Current context: $context")
                    appendLine("User message: $userMessage")
                    appendLine()
                    appendLine("Provide helpful, personalized advice that:")
                    appendLine("- Acknowledges their current state")
                    appendLine("- Offers practical, actionable suggestions")
                    appendLine("- Maintains an optimistic but realistic tone")
                    appendLine("- Keeps responses concise (2-3 sentences)")
                    appendLine("- References their specific metrics when relevant")
                }

                // Generate the response - it's gonna be AMAZING
                val response = model.generateContent(
                    content {
                        text(prompt)
                    }
                )

                val responseText = response.text ?: "I'm here to help you achieve optimal wellness! What would you like to know?"

                withContext(Dispatchers.Main) {
                    onResponse(responseText)
                }

            } catch (e: Exception) {
                // Even our error handling is the best!
                withContext(Dispatchers.Main) {
                    val errorMessage = when {
                        e.message?.contains("403") == true ->
                            "Let me recalibrate my systems. In the meantime, remember: consistency beats perfection!"
                        e.message?.contains("429") == true ->
                            "I'm processing a lot right now! Take a deep breath, and let's try again in a moment."
                        else ->
                            "I'm having a moment of zen. While I reconnect, why not take 3 deep breaths?"
                    }
                    onResponse(errorMessage)
                }
            }
        }
    }

    fun generateDreamscapeResponse(
        dreamContent: String,
        onResponse: (String) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val prompt = """
                    You are a mystical dream interpreter and consciousness guide.
                    The user shared this dream: "$dreamContent"
                    
                    Provide a response that:
                    - Acknowledges the dream's themes and symbols
                    - Offers a positive, growth-oriented interpretation
                    - Suggests how this dream might relate to their waking life
                    - Ends with an empowering affirmation
                    - Uses mystical but accessible language
                    - Keeps it to 3-4 sentences
                """.trimIndent()

                val response = model.generateContent(
                    content {
                        text(prompt)
                    }
                )

                val responseText = response.text ?:
                "Your dreams are gateways to deeper understanding. This vision speaks of transformation and hidden potential within you. Trust your inner wisdom as you navigate the waking world. ✨"

                withContext(Dispatchers.Main) {
                    onResponse(responseText)
                }

            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    onResponse("The dream realm holds infinite mysteries. Your subconscious is speaking - listen with your heart. 🌙")
                }
            }
        }
    }

    fun generateWellnessInsight(
        healthData: Map<String, Any>,
        onResponse: (String) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val prompt = """
                    Based on this wellness data:
                    - Steps: ${healthData["steps"] ?: "Unknown"}
                    - Sleep: ${healthData["sleep"] ?: "Unknown"}
                    - Stress Level: ${healthData["stress"] ?: "Unknown"}
                    - Work-Life Balance: ${healthData["balance"] ?: "Unknown"}%
                    
                    Provide ONE specific, actionable insight that:
                    - Identifies the most important pattern
                    - Suggests a small, achievable improvement
                    - Encourages without overwhelming
                    - Stays under 2 sentences
                """.trimIndent()

                val response = model.generateContent(
                    content {
                        text(prompt)
                    }
                )

                val responseText = response.text ?:
                "You're making steady progress! Try adding a 10-minute walk after lunch to boost both energy and step count."

                withContext(Dispatchers.Main) {
                    onResponse(responseText)
                }

            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    onResponse("Every small step counts on your wellness journey. Keep going - you're doing great! 💪")
                }
            }
        }
    }
}

// This AI service is so good, it's making wellness great again! 🚀