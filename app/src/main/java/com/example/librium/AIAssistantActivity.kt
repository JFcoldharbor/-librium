package com.example.librium

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.example.librium.databinding.ActivityAiAssistantBinding
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.launch
import java.util.*

class AIAssistantActivity : AppCompatActivity() {
    private lateinit var binding: ActivityAiAssistantBinding
    private lateinit var chatAdapter: ChatAdapter
    private lateinit var geminiService: GeminiAIService
    private lateinit var contextEngine: ContextEngine
    private lateinit var speechRecognizer: SpeechRecognizer

    private val messages = mutableListOf<ChatMessage>()
    private var isListening = false

    companion object {
        private const val RECORD_AUDIO_PERMISSION_CODE = 1
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set up immersive mode
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )

        binding = ActivityAiAssistantBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupServices()
        setupUI()
        setupSpeechRecognizer()
        checkAudioPermission()

        // Send welcome message
        sendWelcomeMessage()
    }

    private fun setupServices() {
        geminiService = GeminiAIService()
        contextEngine = ContextEngine()
    }

    private fun setupUI() {
        // Setup RecyclerView
        chatAdapter = ChatAdapter(messages) { message ->
            // Handle card clicks
            when (message.messageType) {
                MessageType.WELLNESS_CARD -> {
                    val data = message.cardData as? WellnessCardData
                    Toast.makeText(this, "Steps: ${data?.steps}, Calories: ${data?.calories}", Toast.LENGTH_SHORT).show()
                }
                MessageType.EMAIL_CARD -> {
                    Toast.makeText(this, "Opening email...", Toast.LENGTH_SHORT).show()
                }
                MessageType.CALENDAR_CARD -> {
                    Toast.makeText(this, "Opening calendar event...", Toast.LENGTH_SHORT).show()
                }
                else -> {}
            }
        }

        binding.messagesRecyclerView.apply {
            layoutManager = LinearLayoutManager(this@AIAssistantActivity)
            adapter = chatAdapter
            itemAnimator?.apply {
                addDuration = 200
                removeDuration = 200
            }
        }

        // Setup send button
        binding.sendButton.setOnClickListener {
            val message = binding.messageInput.text.toString().trim()
            if (message.isNotEmpty()) {
                sendMessage(message)
                binding.messageInput.text?.clear()
            }
        }

        // Setup voice button
        binding.voiceButton.setOnClickListener {
            toggleVoiceInput()
        }

        // Setup menu button
        binding.menuButton.setOnClickListener {
            showUserMenu()
        }

        // Get user info and set initial
        val user = FirebaseAuth.getInstance().currentUser
        val displayName = user?.displayName ?: "Guest"
        val initial = displayName.firstOrNull()?.toString()?.uppercase() ?: "G"
        binding.userInitial.text = initial
    }

    private fun setupSpeechRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Toast.makeText(this, "Speech recognition not available", Toast.LENGTH_SHORT).show()
            binding.voiceButton.isEnabled = false
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                runOnUiThread {
                    binding.voiceButton.setImageResource(R.drawable.ic_mic_active)
                    binding.listeningIndicator.visibility = View.VISIBLE
                }
            }

            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                runOnUiThread {
                    binding.voiceButton.setImageResource(R.drawable.ic_mic)
                    binding.listeningIndicator.visibility = View.GONE
                }
            }

            override fun onError(error: Int) {
                runOnUiThread {
                    binding.voiceButton.setImageResource(R.drawable.ic_mic)
                    binding.listeningIndicator.visibility = View.GONE
                    isListening = false

                    val errorMessage = when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                        SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected"
                        SpeechRecognizer.ERROR_NETWORK -> "Network error"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Permission denied"
                        else -> "Speech recognition error"
                    }
                    Toast.makeText(this@AIAssistantActivity, errorMessage, Toast.LENGTH_SHORT).show()
                }
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    val text = matches[0]
                    binding.messageInput.setText(text)
                    sendMessage(text)
                }
                isListening = false
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    binding.messageInput.setText(matches[0])
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
    }

    private fun checkAudioPermission() {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                RECORD_AUDIO_PERMISSION_CODE
            )
        }
    }

    private fun toggleVoiceInput() {
        if (isListening) {
            speechRecognizer.stopListening()
            isListening = false
            binding.voiceButton.setImageResource(R.drawable.ic_mic)
            binding.listeningIndicator.visibility = View.GONE
        } else {
            startListening()
        }
    }

    private fun startListening() {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            }

            try {
                speechRecognizer.startListening(intent)
                isListening = true
            } catch (e: Exception) {
                Toast.makeText(this, "Failed to start voice input", Toast.LENGTH_SHORT).show()
            }
        } else {
            checkAudioPermission()
        }
    }

    private fun sendWelcomeMessage() {
        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val greeting = when (currentHour) {
            in 5..11 -> "Good morning"
            in 12..16 -> "Good afternoon"
            else -> "Good evening"
        }

        val user = FirebaseAuth.getInstance().currentUser
        val userName = user?.displayName?.split(" ")?.firstOrNull() ?: "there"

        val welcomeMessage = ChatMessage(
            text = "$greeting, $userName! I'm Librium, your AI wellness assistant. I can help you with:\n\n• Health & wellness tracking\n• Daily planning & productivity\n• Mindfulness & stress management\n• Email & calendar insights\n\nHow can I assist you today?",
            isFromUser = false,
            timestamp = System.currentTimeMillis(),
            messageType = MessageType.TEXT
        )

        messages.add(welcomeMessage)
        chatAdapter.notifyItemInserted(messages.size - 1)
        binding.messagesRecyclerView.scrollToPosition(messages.size - 1)
    }

    private fun sendMessage(text: String) {
        // Add user message
        val userMessage = ChatMessage(
            text = text,
            isFromUser = true,
            timestamp = System.currentTimeMillis(),
            messageType = MessageType.TEXT
        )

        messages.add(userMessage)
        chatAdapter.notifyItemInserted(messages.size - 1)
        binding.messagesRecyclerView.scrollToPosition(messages.size - 1)

        // Show typing indicator
        showTypingIndicator()

        // Get AI response
        lifecycleScope.launch {
            try {
                // Get context for the AI
                val context = contextEngine.getCurrentContext()

                // Generate response with Gemini
                val response = geminiService.generateResponse(text)

                hideTypingIndicator()

                // Check if we should show a card based on the query
                val (messageType, cardData) = analyzeResponseForCards(text, response)

                val aiMessage = ChatMessage(
                    text = response,
                    isFromUser = false,
                    timestamp = System.currentTimeMillis(),
                    messageType = messageType,
                    cardData = cardData
                )

                messages.add(aiMessage)
                chatAdapter.notifyItemInserted(messages.size - 1)
                binding.messagesRecyclerView.smoothScrollToPosition(messages.size - 1)

            } catch (e: Exception) {
                hideTypingIndicator()

                val errorMessage = ChatMessage(
                    text = "I apologize, but I'm having trouble connecting right now. Please check your internet connection and try again.",
                    isFromUser = false,
                    timestamp = System.currentTimeMillis(),
                    messageType = MessageType.TEXT
                )

                messages.add(errorMessage)
                chatAdapter.notifyItemInserted(messages.size - 1)
                binding.messagesRecyclerView.scrollToPosition(messages.size - 1)
            }
        }
    }

    private fun analyzeResponseForCards(userQuery: String, aiResponse: String): Pair<MessageType, Any?> {
        val lowerQuery = userQuery.lowercase()

        return when {
            // Wellness card triggers
            lowerQuery.contains("health") ||
                    lowerQuery.contains("wellness") ||
                    lowerQuery.contains("steps") ||
                    lowerQuery.contains("calories") ||
                    lowerQuery.contains("fitness") ||
                    lowerQuery.contains("heart rate") -> {
                val cardData = WellnessCardData(
                    steps = (5000..10000).random(),
                    calories = (1500..2500).random(),
                    heartRate = (60..80).random()
                )
                Pair(MessageType.WELLNESS_CARD, cardData)
            }

            // Email card triggers
            lowerQuery.contains("email") ||
                    lowerQuery.contains("mail") ||
                    lowerQuery.contains("inbox") -> {
                val cardData = EmailCardData(
                    subject = "Weekly Team Sync",
                    sender = "Sarah Johnson",
                    preview = "Hi team, just a reminder about our weekly sync meeting tomorrow at 2 PM. We'll be discussing the Q1 roadmap...",
                    timestamp = System.currentTimeMillis() - (2 * 60 * 60 * 1000), // 2 hours ago
                    isUnread = true
                )
                Pair(MessageType.EMAIL_CARD, cardData)
            }

            // Calendar card triggers
            lowerQuery.contains("calendar") ||
                    lowerQuery.contains("schedule") ||
                    lowerQuery.contains("meeting") ||
                    lowerQuery.contains("appointment") -> {
                val cardData = CalendarCardData(
                    eventTitle = "Team Standup",
                    startTime = "10:00 AM",
                    endTime = "10:30 AM",
                    location = "Conference Room A",
                    attendees = listOf("John", "Sarah", "Mike")
                )
                Pair(MessageType.CALENDAR_CARD, cardData)
            }

            else -> Pair(MessageType.TEXT, null)
        }
    }

    private fun showTypingIndicator() {
        val typingMessage = ChatMessage(
            text = "Librium is thinking...",
            isFromUser = false,
            timestamp = System.currentTimeMillis(),
            messageType = MessageType.TYPING_INDICATOR
        )

        messages.add(typingMessage)
        chatAdapter.notifyItemInserted(messages.size - 1)
        binding.messagesRecyclerView.smoothScrollToPosition(messages.size - 1)
    }

    private fun hideTypingIndicator() {
        // Remove typing indicator
        val lastIndex = messages.size - 1
        if (lastIndex >= 0 && messages[lastIndex].messageType == MessageType.TYPING_INDICATOR) {
            messages.removeAt(lastIndex)
            chatAdapter.notifyItemRemoved(lastIndex)
        }
    }

    private fun showUserMenu() {
        val user = FirebaseAuth.getInstance().currentUser
        val userName = user?.displayName ?: "Guest"
        val email = user?.email ?: "Not logged in"

        // For now, just show a toast. You can implement a proper menu later
        Toast.makeText(
            this,
            "$userName\n$email",
            Toast.LENGTH_LONG
        ).show()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == RECORD_AUDIO_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Toast.makeText(this, "Voice input enabled!", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(
                    this,
                    "Voice input requires microphone permission",
                    Toast.LENGTH_SHORT
                ).show()
                binding.voiceButton.isEnabled = false
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::speechRecognizer.isInitialized) {
            speechRecognizer.destroy()
        }
    }
}