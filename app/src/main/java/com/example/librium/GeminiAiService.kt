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
        modelName = "gemini-pro",
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
                Log.d(TAG, "Received response: $result")

                result
            } catch (e: Exception) {
                Log.e(TAG, "Error generating response", e)
                when {
                    e.message?.contains("API_KEY_INVALID") == true ->
                        "API key error. Please check your Gemini API key configuration."
                    e.message?.contains("QUOTA_EXCEEDED") == true ->
                        "API quota exceeded. Please try again later."
                    e.message?.contains("Network") == true ->
                        "Network error. Please check your internet connection."
                    else ->
                        "Error: ${e.message ?: "Unknown error occurred"}"
                }
            }
        }
    }

    suspend fun generateWellnessAdvice(context: Map<String, Any>): String {
        val timeOfDay = context["timeOfDay"] as? String ?: "day"
        val prompt = """
            As a wellness AI assistant, provide a brief, personalized wellness tip for the $timeOfDay.
            Keep the response friendly, encouraging, and under 2 sentences.
        """.trimIndent()

        return generateResponse(prompt)
    }
}