package com.example.equilibrium

import android.util.Log
import com.google.ai.client.generativeai.GenerativeModel
import com.google.ai.client.generativeai.type.generationConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class GeminiAIService {

    // 🔒 SECURE: API key comes from BuildConfig
    private val apiKey = "AIzaSyAy2nOtXt26B8whU7sCLkd2NsXG--i77Hw"  // TEMP

    private val generativeModel = GenerativeModel(
        modelName = "gemini-pro",
        apiKey = apiKey,
        generationConfig = generationConfig {
            temperature = 0.7f
            topK = 40
            topP = 0.95f
            maxOutputTokens = 1024
        }
    )

    suspend fun generateResponse(
        userMessage: String,
        context: ContextEngine.AIContext,
        userContext: String = ""
    ): AIResponse {
        return withContext(Dispatchers.IO) {
            try {
                // DEBUG: Check if API key is available
                Log.d("EquilibriumAI", "🔧 DEBUG: API Key length: ${apiKey.length}")
                Log.d("EquilibriumAI", "🔧 DEBUG: API Key starts with: ${apiKey.take(10)}...")

                if (apiKey.isEmpty()) {
                    Log.d("EquilibriumAI", "🔧 DEBUG: API Key is empty! Using fallback.")
                    return@withContext getFallbackResponse(userMessage, context).copy(
                        message = "🔧 API key is missing! Using local responses. Check your local.properties file."
                    )
                }

                val prompt = buildContextualPrompt(userMessage, context, userContext)
                Log.d("EquilibriumAI", "🔧 DEBUG: Sending prompt to Gemini...")
                Log.d("EquilibriumAI", "🔧 DEBUG: Prompt length: ${prompt.length}")

                val response = generativeModel.generateContent(prompt)
                val responseText = response.text ?: "I'm thinking... can you try asking that again?"

                Log.d("EquilibriumAI", "🔧 DEBUG: Gemini responded: ${responseText.take(50)}...")

                // Analyze the response to determine if we should show cards
                val suggestedCards = analyzeResponseForCards(userMessage, responseText)

                AIResponse(
                    message = "✨ Gemini AI: $responseText",  // DEBUG: Mark real Gemini responses
                    suggestedCards = suggestedCards,
                    confidence = 0.9f,
                    shouldShowTyping = true
                )

            } catch (e: Exception) {
                Log.e("EquilibriumAI", "🔧 DEBUG: Gemini API failed: ${e.message}")
                Log.e("EquilibriumAI", "🔧 DEBUG: Full Gemini exception:", e)
                // Fallback to contextual responses if API fails
                getFallbackResponse(userMessage, context).copy(
                    message = "🤖 Local AI: ${getFallbackResponse(userMessage, context).message}"
                )
            }
        }
    }

    private fun buildContextualPrompt(
        userMessage: String,
        context: ContextEngine.AIContext,
        userContext: String
    ): String {
        val timeContext = when (context.timeOfDay) {
            ContextEngine.TimeOfDay.EARLY_MORNING -> "It's early morning (5-8 AM), perfect time for planning and setting intentions."
            ContextEngine.TimeOfDay.MORNING -> "It's morning (8-11 AM), prime time for productivity and getting things done."
            ContextEngine.TimeOfDay.MIDDAY -> "It's midday (11 AM-2 PM), good time for wellness checks and staying energized."
            ContextEngine.TimeOfDay.AFTERNOON -> "It's afternoon (2-6 PM), peak productivity time with some potential for afternoon fatigue."
            ContextEngine.TimeOfDay.EVENING -> "It's evening (6-9 PM), time for reflection, winding down, and planning ahead."
            ContextEngine.TimeOfDay.NIGHT -> "It's night time (9 PM+), time for rest, recovery, and gentle reminders."
        }

        val systemPrompt = """
        You are Equilibrium AI, a personal wellness and productivity assistant. You help users with:
        - Wellness tracking (steps, calories, hydration, sleep)
        - Communication management (emails, texts)
        - Calendar and time management
        - Productivity optimization
        - Goal setting and motivation
        
        Current context: $timeContext
        
        Your personality traits:
        - Encouraging and supportive but not overly enthusiastic
        - Smart and helpful with practical advice
        - Time-aware and contextually relevant
        - Concise but warm responses (2-3 sentences max usually)
        - Use emojis sparingly but effectively
        
        IMPORTANT: When users ask about meetings, calendar, wellness, or communication:
        - If they want to SEE data (using words like "show", "check", "display"), mention that you can show them the information
        - If they want to DISCUSS or get ADVICE (using words like "tell me about", "should I", "how", "why"), provide conversational advice WITHOUT mentioning showing data
        - Focus on giving helpful advice and insights, not just data display
        
        Current user priority: ${context.priority}
        User's recent context: $userContext
        
        User message: "$userMessage"
        
        Respond as Equilibrium AI with advice appropriate for the current time and context. Be conversational and helpful, not just a data display tool.
        """.trimIndent()

        return systemPrompt
    }

    private fun analyzeResponseForCards(userMessage: String, aiResponse: String): List<String> {
        val cards = mutableListOf<String>()

        val lowerUserMessage = userMessage.lowercase()
        val lowerAIResponse = aiResponse.lowercase()

        // Only show cards if user is ASKING FOR DATA, not discussing it
        val isRequestingData = lowerUserMessage.contains("show") ||
                lowerUserMessage.contains("check") ||
                lowerUserMessage.contains("see") ||
                lowerUserMessage.contains("what's") ||
                lowerUserMessage.contains("how many") ||
                lowerUserMessage.contains("display")

        val isDiscussing = lowerUserMessage.contains("tell me about") ||
                lowerUserMessage.contains("explain") ||
                lowerUserMessage.contains("why") ||
                lowerUserMessage.contains("how") ||
                lowerUserMessage.contains("should i") ||
                lowerUserMessage.contains("when")

        // If user is just discussing, don't auto-show cards
        if (isDiscussing && !isRequestingData) {
            return emptyList()
        }

        // Wellness-related triggers - only for data requests
        if ((lowerUserMessage.contains("show") && (lowerUserMessage.contains("steps") || lowerUserMessage.contains("wellness"))) ||
            (lowerUserMessage.contains("check") && (lowerUserMessage.contains("health") || lowerUserMessage.contains("fitness"))) ||
            lowerUserMessage.contains("my calories") || lowerUserMessage.contains("my water") ||
            (isRequestingData && (lowerUserMessage.contains("wellness") || lowerUserMessage.contains("steps")))) {
            cards.add("wellness")
        }

        // Communication triggers - only for data requests
        if ((lowerUserMessage.contains("check") && (lowerUserMessage.contains("email") || lowerUserMessage.contains("message"))) ||
            lowerUserMessage.contains("show me my emails") ||
            lowerUserMessage.contains("what emails") ||
            (isRequestingData && (lowerUserMessage.contains("email") || lowerUserMessage.contains("text")))) {
            cards.add("communication")
        }

        // Calendar triggers - only for data requests
        if ((lowerUserMessage.contains("show") && (lowerUserMessage.contains("calendar") || lowerUserMessage.contains("meeting"))) ||
            lowerUserMessage.contains("check my schedule") ||
            lowerUserMessage.contains("what meetings") ||
            lowerUserMessage.contains("when is") ||
            (isRequestingData && (lowerUserMessage.contains("calendar") || lowerUserMessage.contains("schedule")))) {
            cards.add("calendar")
        }

        return cards
    }

    private fun getFallbackResponse(userMessage: String, context: ContextEngine.AIContext): AIResponse {
        val lowerMessage = userMessage.lowercase()

        val fallbackMessage = when {
            lowerMessage.contains("steps") || lowerMessage.contains("wellness") -> {
                when (context.timeOfDay) {
                    ContextEngine.TimeOfDay.MORNING -> "Good morning! Perfect time to check your wellness progress. Let me show you where you stand today! 📊"
                    ContextEngine.TimeOfDay.AFTERNOON -> "Great time for a wellness check-in! How's your energy level? Let me pull up your stats! ⚡"
                    ContextEngine.TimeOfDay.EVENING -> "Evening wellness review coming up! Let's see how you did with today's goals! 🌆"
                    else -> "Let me check your current wellness status! 🏃‍♂️"
                }
            }

            lowerMessage.contains("email") || lowerMessage.contains("communication") -> {
                "I can help you stay on top of your communication! Let me check what's waiting for you 📧"
            }

            lowerMessage.contains("calendar") || lowerMessage.contains("schedule") -> {
                "Time to check your schedule! Let me see what's coming up for you 📅"
            }

            lowerMessage.contains("hello") || lowerMessage.contains("hi") -> {
                context.greeting
            }

            else -> {
                "I'm here to help with your wellness, communication, and productivity! What would you like to focus on? 🤖"
            }
        }

        return AIResponse(
            message = fallbackMessage,
            suggestedCards = analyzeResponseForCards(userMessage, fallbackMessage),
            confidence = 0.6f,
            shouldShowTyping = false
        )
    }
}

data class AIResponse(
    val message: String,
    val suggestedCards: List<String>,
    val confidence: Float,
    val shouldShowTyping: Boolean
)