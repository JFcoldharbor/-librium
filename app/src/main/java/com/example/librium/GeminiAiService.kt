package com.example.librium

import com.google.ai.client.generativeai.GenerativeModel
import com.google.ai.client.generativeai.type.content
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import android.util.Log

class GeminiAIService {
    companion object {
        private const val TAG = "GeminiAIService"
        // Your API key from Google AI Studio
        private const val API_KEY = "AIzaSyBGtoim3ha1WGeNv4hjw7pL-XPDBhTnuk0"
    }

    private val generativeModel = GenerativeModel(
        modelName = "gemini-1.5-flash", // Change from "gemini-pro"
        apiKey = API_KEY
    )

    suspend fun generateResponse(prompt: String): String {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Sending prompt to Gemini: $prompt")

                val response = generativeModel.generateContent(
                    content {
                        text(prompt)
                    }
                )

                val result = response.text ?: "I couldn't generate a response. Please try again."
                Log.d(TAG, "Received response: ${result.take(100)}...") // Log first 100 chars

                result
            } catch (e: Exception) {
                Log.e(TAG, "Error generating response", e)
                handleError(e)
            }
        }
    }

    private fun handleError(e: Exception): String {
        return when {
            e.message?.contains("API_KEY_INVALID") == true ->
                "There's an issue with the API configuration. Please check the setup."
            e.message?.contains("QUOTA_EXCEEDED") == true ->
                "I've reached my response limit for now. Please try again in a moment."
            e.message?.contains("404") == true ->
                "I'm having trouble connecting to my AI service. Please check your internet connection."
            e.message?.contains("timeout", ignoreCase = true) == true ->
                "The response is taking too long. Please try again."
            else ->
                "I encountered an error: ${e.message ?: "Unknown error"}. Please try again."
        }
    }

    suspend fun generateWellnessAdvice(context: Map<String, Any>): String {
        val timeOfDay = context["timeOfDay"] as? String ?: "day"
        val userState = context["userState"] as? String ?: "active"

        val prompt = """
            As Librium, a friendly wellness AI assistant, provide a brief, personalized wellness tip.
            Time of day: $timeOfDay
            User state: $userState
            
            Keep the response:
            - Encouraging and positive
            - Under 3 sentences
            - Actionable
            - Focused on wellness, health, or productivity
        """.trimIndent()

        return generateResponse(prompt)
    }
}