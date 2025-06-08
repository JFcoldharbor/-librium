package com.example.librium

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.core.widget.NestedScrollView
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class AIChatActivity : AppCompatActivity(), TextToSpeech.OnInitListener {

    private lateinit var mainContainer: LinearLayout
    private lateinit var chatContainer: LinearLayout
    private lateinit var messageInput: EditText
    private lateinit var sendButton: Button
    private lateinit var scrollView: NestedScrollView
    private lateinit var geminiService: GeminiAIService
    private lateinit var textToSpeech: TextToSpeech

    private val chatHistory = mutableListOf<ChatMessage>()
    private var isAITyping = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize services
        geminiService = GeminiAIService(this)
        textToSpeech = TextToSpeech(this, this)

        // Main layout
        mainContainer = LinearLayout(this)
        mainContainer.orientation = LinearLayout.VERTICAL
        mainContainer.setBackgroundColor(Color.parseColor("#0F172A"))
        setContentView(mainContainer)

        createHeader()
        createChatArea()
        createInputArea()
        addWelcomeMessage()
    }

    private fun createHeader() {
        val header = LinearLayout(this)
        header.orientation = LinearLayout.HORIZONTAL
        header.gravity = Gravity.CENTER_VERTICAL
        header.setPadding(24, 60, 24, 24)

        val headerBg = GradientDrawable()
        headerBg.colors = intArrayOf(Color.parseColor("#FF5722"), Color.parseColor("#E91E63"))
        headerBg.orientation = GradientDrawable.Orientation.LEFT_RIGHT
        headerBg.cornerRadii = floatArrayOf(0f, 0f, 0f, 0f, 50f, 50f, 50f, 50f)
        header.background = headerBg

        // Back button
        val backButton = Button(this)
        backButton.text = "←"
        backButton.textSize = 24f
        backButton.setTextColor(Color.WHITE)

        val backBg = GradientDrawable()
        backBg.shape = GradientDrawable.OVAL
        backBg.setColor(Color.parseColor("#FFFFFF20"))
        backButton.background = backBg

        val backParams = LinearLayout.LayoutParams(80, 80)
        backButton.layoutParams = backParams
        backButton.setOnClickListener { finish() }

        // Title
        val titleContainer = LinearLayout(this)
        titleContainer.orientation = LinearLayout.VERTICAL
        val titleParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        titleParams.marginStart = 20
        titleContainer.layoutParams = titleParams

        val title = TextView(this)
        title.text = "🤖 AI Wellness Coach"
        title.textSize = 24f
        title.setTextColor(Color.WHITE)
        title.typeface = Typeface.DEFAULT_BOLD

        val subtitle = TextView(this)
        subtitle.text = "Your personal wellness companion"
        subtitle.textSize = 14f
        subtitle.setTextColor(Color.parseColor("#FFFFFF80"))

        titleContainer.addView(title)
        titleContainer.addView(subtitle)

        // Voice button
        val voiceButton = Button(this)
        voiceButton.text = "🔊"
        voiceButton.textSize = 20f
        voiceButton.setTextColor(Color.WHITE)

        val voiceBg = GradientDrawable()
        voiceBg.shape = GradientDrawable.OVAL
        voiceBg.setColor(Color.parseColor("#FFFFFF20"))
        voiceButton.background = voiceBg

        val voiceParams = LinearLayout.LayoutParams(80, 80)
        voiceButton.layoutParams = voiceParams
        voiceButton.setOnClickListener {
            Toast.makeText(this, "Voice mode toggled!", Toast.LENGTH_SHORT).show()
        }

        header.addView(backButton)
        header.addView(titleContainer)
        header.addView(voiceButton)
        mainContainer.addView(header)
    }

    private fun createChatArea() {
        scrollView = NestedScrollView(this)
        val scrollParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            0,
            1f
        )
        scrollView.layoutParams = scrollParams
        scrollView.setPadding(20, 20, 20, 20)

        chatContainer = LinearLayout(this)
        chatContainer.orientation = LinearLayout.VERTICAL
        chatContainer.setPadding(0, 0, 0, 100)

        scrollView.addView(chatContainer)
        mainContainer.addView(scrollView)
    }

    private fun createInputArea() {
        val inputContainer = LinearLayout(this)
        inputContainer.orientation = LinearLayout.HORIZONTAL
        inputContainer.gravity = Gravity.CENTER_VERTICAL
        inputContainer.setPadding(20, 16, 20, 32)

        val inputBg = GradientDrawable()
        inputBg.setColor(Color.parseColor("#1E293B"))
        inputBg.cornerRadii = floatArrayOf(50f, 50f, 50f, 50f, 0f, 0f, 0f, 0f)
        inputContainer.background = inputBg
        inputContainer.elevation = 16f

        // Message input
        messageInput = EditText(this)
        messageInput.hint = "Ask me anything about wellness..."
        messageInput.setHintTextColor(Color.parseColor("#64748B"))
        messageInput.setTextColor(Color.WHITE)
        messageInput.textSize = 16f

        val inputFieldBg = GradientDrawable()
        inputFieldBg.setColor(Color.parseColor("#334155"))
        inputFieldBg.cornerRadius = 30f
        messageInput.background = inputFieldBg
        messageInput.setPadding(24, 16, 24, 16)

        val inputParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        inputParams.marginEnd = 16
        messageInput.layoutParams = inputParams

        // Send button
        sendButton = Button(this)
        sendButton.text = "🚀"
        sendButton.textSize = 20f
        sendButton.setTextColor(Color.WHITE)

        val sendBg = GradientDrawable()
        sendBg.orientation = GradientDrawable.Orientation.TL_BR
        sendBg.colors = intArrayOf(Color.parseColor("#FF5722"), Color.parseColor("#E91E63"))
        sendBg.shape = GradientDrawable.OVAL
        sendButton.background = sendBg

        val sendParams = LinearLayout.LayoutParams(80, 80)
        sendButton.layoutParams = sendParams
        sendButton.elevation = 8f
        sendButton.isEnabled = false
        sendButton.setOnClickListener { sendMessage() }

        // Text watcher
        messageInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                sendButton.isEnabled = !s.isNullOrBlank()
                sendButton.alpha = if (s.isNullOrBlank()) 0.5f else 1.0f
            }
        })

        inputContainer.addView(messageInput)
        inputContainer.addView(sendButton)
        mainContainer.addView(inputContainer)
    }

    private fun addWelcomeMessage() {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val greeting = when (hour) {
            in 5..11 -> "Good morning"
            in 12..16 -> "Good afternoon"
            in 17..21 -> "Good evening"
            else -> "Good night"
        }

        val welcomeText = "$greeting! I'm your AI wellness companion. 🌟\n\n" +
                "I'm here to help you with:\n" +
                "• Wellness check-ins and advice\n" +
                "• Motivation and energy boosts\n" +
                "• Work-life balance insights\n" +
                "• Dream interpretation\n" +
                "• Personal growth guidance\n\n" +
                "What can I help you with today?"

        addAIMessage(welcomeText)
    }

    private fun sendMessage() {
        val userText = messageInput.text.toString().trim()
        if (userText.isEmpty()) return

        addUserMessage(userText)
        messageInput.text.clear()
        hideKeyboard()

        val context = buildContextString()

        lifecycleScope.launch {
            delay(1500)
            geminiService.generateResponse(userText, context) { response ->
                addAIMessage(response)
            }
        }
    }

    private fun buildContextString(): String {
        val calendar = Calendar.getInstance()
        val timeOfDay = when (calendar.get(Calendar.HOUR_OF_DAY)) {
            in 5..11 -> "morning"
            in 12..16 -> "afternoon"
            in 17..21 -> "evening"
            else -> "night"
        }

        val dayOfWeek = SimpleDateFormat("EEEE", Locale.getDefault()).format(Date())

        return "Current time context: $timeOfDay on $dayOfWeek\n" +
                "User wellness stats:\n" +
                "- Steps today: 7,542/10,000\n" +
                "- Sleep last night: 7.5 hours\n" +
                "- Energy level: Good\n" +
                "- Work-life balance: 68%\n" +
                "- Stress level: Medium\n" +
                "- Current mood: Motivated"
    }

    private fun addUserMessage(text: String) {
        val messageCard = createMessageCard(text, true)
        chatContainer.addView(messageCard)
        scrollView.post { scrollView.fullScroll(View.FOCUS_DOWN) }
        chatHistory.add(ChatMessage(text, true))
    }

    private fun addAIMessage(text: String) {
        val messageCard = createMessageCard(text, false)
        chatContainer.addView(messageCard)

        messageCard.alpha = 0f
        messageCard.animate().alpha(1f).setDuration(500).start()

        scrollView.post { scrollView.fullScroll(View.FOCUS_DOWN) }
        chatHistory.add(ChatMessage(text, false))

        if (::textToSpeech.isInitialized && !textToSpeech.isSpeaking) {
            textToSpeech.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
        }
    }

    private fun createMessageCard(text: String, isUser: Boolean): LinearLayout {
        val messageContainer = LinearLayout(this)
        messageContainer.orientation = LinearLayout.HORIZONTAL
        val containerParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        containerParams.setMargins(0, 8, 0, 8)
        messageContainer.layoutParams = containerParams
        messageContainer.gravity = if (isUser) Gravity.END else Gravity.START

        val messageCard = CardView(this)
        messageCard.radius = 24f
        messageCard.cardElevation = 8f

        val cardParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        val maxWidth = (resources.displayMetrics.widthPixels * 0.8f).toInt()
        cardParams.width = maxWidth
        if (isUser) {
            cardParams.marginStart = (resources.displayMetrics.widthPixels * 0.2f).toInt()
        } else {
            cardParams.marginEnd = (resources.displayMetrics.widthPixels * 0.2f).toInt()
        }
        messageCard.layoutParams = cardParams

        val messageContent = LinearLayout(this)
        messageContent.orientation = LinearLayout.HORIZONTAL
        messageContent.setPadding(20, 16, 20, 16)

        val contentBg = GradientDrawable()
        if (isUser) {
            contentBg.orientation = GradientDrawable.Orientation.TL_BR
            contentBg.colors = intArrayOf(Color.parseColor("#FF5722"), Color.parseColor("#E91E63"))
        } else {
            contentBg.setColor(Color.parseColor("#334155"))
        }
        contentBg.cornerRadius = 24f
        messageContent.background = contentBg

        // Avatar
        if (!isUser) {
            val avatar = TextView(this)
            avatar.text = "🤖"
            avatar.textSize = 20f
            avatar.setPadding(0, 0, 12, 0)
            messageContent.addView(avatar)
        }

        // Message text
        val messageText = TextView(this)
        messageText.text = text
        messageText.textSize = 16f
        messageText.setTextColor(Color.WHITE)
        messageContent.addView(messageText)

        // User avatar
        if (isUser) {
            val avatar = TextView(this)
            avatar.text = "👤"
            avatar.textSize = 20f
            avatar.setPadding(12, 0, 0, 0)
            messageContent.addView(avatar)
        }

        messageCard.addView(messageContent)
        messageContainer.addView(messageCard)
        return messageContainer
    }

    private fun hideKeyboard() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(messageInput.windowToken, 0)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            textToSpeech.language = Locale.getDefault()
            textToSpeech.setSpeechRate(0.9f)
        }
    }

    override fun onDestroy() {
        if (::textToSpeech.isInitialized) {
            textToSpeech.stop()
            textToSpeech.shutdown()
        }
        super.onDestroy()
    }
}