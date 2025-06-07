package com.example.librium

import android.animation.ValueAnimator
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import android.app.AlertDialog
import android.speech.tts.TextToSpeech
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    // Properties
    private lateinit var currentInput: EditText
    private lateinit var scrollView: ScrollView
    private lateinit var mainContainer: LinearLayout
    private lateinit var motivationalCard: CardView
    private lateinit var motivationalText: TextView
    private lateinit var wellnessCard: CardView
    private lateinit var wellnessContent: LinearLayout
    private lateinit var scheduleCard: CardView
    private lateinit var scheduleContent: LinearLayout

    // AI Services
    private var geminiService: GeminiAIService? = null
    private lateinit var contextEngine: ContextEngine
    private lateinit var textToSpeech: TextToSpeech
    private var isTTSReady = false

    // Check-in scheduling
    private val checkInHandler = Handler(Looper.getMainLooper())
    private lateinit var checkInRunnable: Runnable
    private var lastCheckInHour = -1

    // Wellness stats rotation
    private var currentStatIndex = 0
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var statRotationRunnable: Runnable

    companion object {
        private const val TAG = "MainActivity"
        private const val STAT_ROTATION_DELAY = 3000L
        private const val CHANNEL_ID = "librium_ai_channel"
        private const val NOTIFICATION_PERMISSION_CODE = 123
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Main layout with gradient background
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = createGradientBackground()
        }

        // ScrollView setup
        scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        mainContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 0, 24, 24)
        }

        scrollView.addView(mainContainer)
        mainLayout.addView(scrollView)

        // Initialize services FIRST before creating cards
        initializeServices()
        createNotificationChannel()
        requestNotificationPermission()

        // Create header
        createHeader(mainLayout)

        // Create cards (AFTER services are initialized)
        createMotivationalCard()
        createWellnessCard()
        createScheduleCard()
        createQuickActionCards()

        // Create root layout with floating button
        val rootLayout = FrameLayout(this).apply {
            addView(mainLayout)
        }

        // Add floating AI chat button
        val aiChatButton = Button(this).apply {
            text = "🤖"
            textSize = 20f
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFFFF5722.toInt())
            }
            layoutParams = FrameLayout.LayoutParams(150, 150).apply {
                gravity = Gravity.BOTTOM or Gravity.END
                setMargins(0, 0, 32, 32)
            }
            elevation = 12f
            setOnClickListener {
                showAIChatDialog()
            }
        }
        rootLayout.addView(aiChatButton)

        setContentView(rootLayout)

        // Start rotations and updates
        startStatRotation()
        scheduleAICheckIns()
        updateScheduleCard()

        // Periodic updates
        handler.postDelayed(object : Runnable {
            override fun run() {
                updateMotivationalMessage()
                updateScheduleCard()
                handler.postDelayed(this, 60000)
            }
        }, 60000)
    }

    private fun initializeServices() {
        try {
            geminiService = GeminiAIService()
            contextEngine = ContextEngine()

            // Initialize Text-to-Speech
            textToSpeech = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    val result = textToSpeech.setLanguage(Locale.US)
                    if (result != TextToSpeech.LANG_MISSING_DATA &&
                        result != TextToSpeech.LANG_NOT_SUPPORTED) {
                        isTTSReady = true
                        textToSpeech.setPitch(1.1f)
                        textToSpeech.setSpeechRate(0.95f)
                        Log.d(TAG, "Text-to-Speech initialized successfully")
                    }
                } else {
                    Log.e(TAG, "Text-to-Speech initialization failed")
                }
            }

            Log.d(TAG, "All services initialized successfully!")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize services", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Librium AI Check-ins"
            val descriptionText = "Wellness check-ins from your AI assistant"
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_CODE
                )
            }
        }
    }

    private fun scheduleAICheckIns() {
        checkInRunnable = object : Runnable {
            override fun run() {
                val calendar = Calendar.getInstance()
                val hour = calendar.get(Calendar.HOUR_OF_DAY)

                // Only check in once per hour
                if (hour != lastCheckInHour) {
                    lastCheckInHour = hour

                    when (hour) {
                        9 -> performCheckIn("Morning check! How'd you sleep? 😴", true)
                        12 -> performCheckIn("Lunch time! Have you eaten? 🥗", true)
                        15 -> performCheckIn("Afternoon stretch? Your body needs movement! 🧘", false)
                        18 -> performCheckIn("Evening wind-down. How was your day? 🌅", true)
                    }
                }

                // Schedule next check (every 30 minutes)
                checkInHandler.postDelayed(this, 1800000)
            }
        }
        checkInHandler.post(checkInRunnable)
    }

    private fun performCheckIn(message: String, showDialog: Boolean) {
        // Speak the check-in
        speakText(message)

        // Show notification
        showCheckInNotification(message)

        // Optionally show dialog
        if (showDialog) {
            showAICheckInDialog(message)
        }
    }

    private fun showCheckInNotification(message: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("🤖 Librium AI Check-in")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)

        with(NotificationManagerCompat.from(this)) {
            notify(System.currentTimeMillis().toInt(), builder.build())
        }
    }

    private fun showAICheckInDialog(message: String) {
        runOnUiThread {
            AlertDialog.Builder(this)
                .setTitle("🤖 Librium Check-In")
                .setMessage(message)
                .setPositiveButton("I'm good!") { _, _ ->
                    speakText("Great to hear! Keep up the good work!")
                }
                .setNeutralButton("Let's talk") { _, _ ->
                    showAIChatDialog()
                }
                .setNegativeButton("Not now", null)
                .show()
        }
    }

    private fun speakText(text: String) {
        if (isTTSReady) {
            textToSpeech.speak(text, TextToSpeech.QUEUE_FLUSH, null, "LibriumSpeech")
        }
    }

    private fun createGradientBackground(): GradientDrawable {
        return GradientDrawable().apply {
            orientation = GradientDrawable.Orientation.TOP_BOTTOM
            colors = intArrayOf(
                0xFF0F172A.toInt(),
                0xFF1E1B3A.toInt()
            )
        }
    }

    private fun createHeader(parent: ViewGroup) {
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(24, 48, 24, 24)
            gravity = Gravity.CENTER_VERTICAL
        }

        val title = TextView(this).apply {
            text = "Librium AI"
            textSize = 32f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
        }
        header.addView(title)

        parent.addView(header)
    }

    private fun createMotivationalCard() {
        motivationalCard = CardView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
            radius = 24f
            cardElevation = 8f
            setCardBackgroundColor(Color.TRANSPARENT)
        }

        val gradientBg = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                orientation = GradientDrawable.Orientation.TL_BR
                colors = intArrayOf(
                    0xFFFF5722.toInt(),
                    0xFF9C27B0.toInt()
                )
                cornerRadius = 24f
            }
            setPadding(24, 24, 24, 24)
        }

        motivationalText = TextView(this).apply {
            text = contextEngine.getWellnessPrompt()
            textSize = 18f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
        }
        gradientBg.addView(motivationalText)

        val quote = TextView(this).apply {
            text = contextEngine.getMotivationalQuote()
            textSize = 14f
            setTextColor(0xFFFFFFFF.toInt())
            setPadding(0, 8, 0, 0)
        }
        gradientBg.addView(quote)

        motivationalCard.addView(gradientBg)
        mainContainer.addView(motivationalCard)
    }

    private fun createWellnessCard() {
        wellnessCard = CardView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
            radius = 24f
            cardElevation = 8f
            setCardBackgroundColor(0xFF1E293B.toInt())

            setOnClickListener {
                startActivity(Intent(this@MainActivity, WellnessActivity::class.java))
                overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
            }
        }

        wellnessContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        header.addView(TextView(this).apply {
            text = "💪 Wellness"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
        })

        header.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        })

        header.addView(TextView(this).apply {
            text = "Tap for details →"
            textSize = 12f
            setTextColor(0xFF94A3B8.toInt())
        })

        wellnessContent.addView(header)

        val statsContainer = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                200
            )
        }

        createStatView("👟 Steps", "7,542", "/ 10,000", 0.75f, true).let {
            statsContainer.addView(it)
        }

        createStatView("🔥 Calories", "1,850", "burned", 0.62f, false).let {
            statsContainer.addView(it)
        }

        createStatView("❤️ Heart Rate", "72", "bpm", 0.9f, false).let {
            statsContainer.addView(it)
        }

        createStatView("💧 Water", "5", "/ 8 glasses", 0.625f, false).let {
            statsContainer.addView(it)
        }

        wellnessContent.addView(statsContainer)
        wellnessCard.addView(wellnessContent)
        mainContainer.addView(wellnessCard)
    }

    private fun createStatView(
        icon: String,
        value: String,
        label: String,
        progress: Float,
        visible: Boolean
    ): LinearLayout {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            visibility = if (visible) View.VISIBLE else View.GONE
            setPadding(0, 24, 0, 0)

            addView(TextView(this@MainActivity).apply {
                text = "$icon $value"
                textSize = 36f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            })

            addView(TextView(this@MainActivity).apply {
                text = label
                textSize = 16f
                setTextColor(0xFF94A3B8.toInt())
                gravity = Gravity.CENTER
                setPadding(0, 8, 0, 16)
            })

            addView(createProgressBar(progress))
        }
    }

    private fun createProgressBar(progress: Float): View {
        val progressContainer = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                16
            )
        }

        val bgBar = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            background = GradientDrawable().apply {
                setColor(0xFF334155.toInt())
                cornerRadius = 8f
            }
        }
        progressContainer.addView(bgBar)

        val progressBar = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                (resources.displayMetrics.widthPixels * progress * 0.8f).toInt(),
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            background = GradientDrawable().apply {
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
                colors = intArrayOf(
                    0xFFFF5722.toInt(),
                    0xFF9C27B0.toInt()
                )
                cornerRadius = 8f
            }
        }
        progressContainer.addView(progressBar)

        return progressContainer
    }

    private fun createScheduleCard() {
        scheduleCard = CardView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
            radius = 24f
            cardElevation = 8f
            setCardBackgroundColor(0xFF1E293B.toInt())

            setOnClickListener {
                startActivity(Intent(this@MainActivity, ScheduleActivity::class.java))
                overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
            }
        }

        scheduleContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
        }

        val header = TextView(this).apply {
            text = "📅 Today's Schedule"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 16)
        }
        scheduleContent.addView(header)

        scheduleCard.addView(scheduleContent)
        mainContainer.addView(scheduleCard)
    }

    private fun updateScheduleCard() {
        scheduleContent.removeAllViews()

        scheduleContent.addView(TextView(this).apply {
            text = "📅 Today's Schedule"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 16)
        })

        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val meetings = getScheduleForTime(currentHour)

        meetings.forEach { (time, title, status) ->
            val meetingView = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, 8, 0, 8)
                gravity = Gravity.CENTER_VERTICAL
            }

            meetingView.addView(TextView(this).apply {
                text = time
                setTextColor(Color.WHITE)
                textSize = 12f
                background = GradientDrawable().apply {
                    setColor(
                        when (status) {
                            "completed" -> 0xFF6B7280.toInt()
                            "current" -> 0xFFFF5722.toInt()
                            else -> 0xFF9C27B0.toInt()
                        }
                    )
                    cornerRadius = 20f
                }
                setPadding(16, 8, 16, 8)
            })

            meetingView.addView(TextView(this).apply {
                text = if (status == "completed") "✓ $title" else title
                setTextColor(if (status == "completed") 0xFF94A3B8.toInt() else Color.WHITE)
                textSize = 16f
                setPadding(16, 0, 0, 0)
            })

            scheduleContent.addView(meetingView)
        }

        val nextMeeting = getNextMeeting(currentHour)
        if (nextMeeting != null) {
            scheduleContent.addView(TextView(this).apply {
                text = "⏰ Reminder: $nextMeeting in 30 minutes"
                textSize = 14f
                setTextColor(0xFFFF5722.toInt())
                setPadding(0, 16, 0, 0)
            })
        }
    }

    private fun getScheduleForTime(currentHour: Int): List<Triple<String, String, String>> {
        val allMeetings = listOf(
            Triple("9:00 AM", "Team Standup", if (currentHour > 9) "completed" else "upcoming"),
            Triple(
                "11:00 AM",
                "Design Review",
                if (currentHour > 11) "completed" else if (currentHour == 11) "current" else "upcoming"
            ),
            Triple(
                "2:00 PM",
                "Client Call",
                if (currentHour > 14) "completed" else if (currentHour == 14) "current" else "upcoming"
            ),
            Triple(
                "4:00 PM",
                "Project Sync",
                if (currentHour > 16) "completed" else if (currentHour == 16) "current" else "upcoming"
            )
        )

        return allMeetings.filter { (_, _, status) ->
            status == "current" ||
                    (status == "completed" && allMeetings.count { it.third == "completed" } <= 2) ||
                    (status == "upcoming" && allMeetings.count { it.third == "upcoming" } <= 2)
        }
    }

    private fun getNextMeeting(currentHour: Int): String? {
        return when {
            currentHour < 9 -> "Team Standup"
            currentHour < 11 -> "Design Review"
            currentHour < 14 -> "Client Call"
            currentHour < 16 -> "Project Sync"
            else -> null
        }
    }

    private fun createQuickActionCards() {
        val actionsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, 16)
        }

        val emailCard = createActionCard("📧", "Communication", "Contacts") {
            startActivity(Intent(this, CommunicationActivity::class.java))
            overridePendingTransition(android.R.anim.slide_in_left, android.R.anim.slide_out_right)
        }
        actionsContainer.addView(emailCard)

        mainContainer.addView(actionsContainer)
    }

    private fun createActionCard(
        icon: String,
        title: String,
        subtitle: String,
        onClick: () -> Unit
    ): CardView {
        return CardView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            radius = 20f
            cardElevation = 4f
            setCardBackgroundColor(0xFF1E293B.toInt())
            setOnClickListener { onClick() }

            val content = LinearLayout(this@MainActivity).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(16, 24, 16, 24)
            }

            content.addView(TextView(this@MainActivity).apply {
                text = icon
                textSize = 32f
                gravity = Gravity.CENTER
            })

            content.addView(TextView(this@MainActivity).apply {
                text = title
                textSize = 16f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                setPadding(0, 8, 0, 0)
            })

            content.addView(TextView(this@MainActivity).apply {
                text = subtitle
                textSize = 12f
                setTextColor(0xFF94A3B8.toInt())
                gravity = Gravity.CENTER
            })

            addView(content)
        }
    }

    private fun startStatRotation() {
        statRotationRunnable = object : Runnable {
            override fun run() {
                val currentStat =
                    (wellnessContent.getChildAt(1) as FrameLayout).getChildAt(currentStatIndex)
                currentStat.animate()
                    .alpha(0f)
                    .setDuration(300)
                    .withEndAction {
                        currentStat.visibility = View.GONE

                        currentStatIndex = (currentStatIndex + 1) % 4
                        val nextStat = (wellnessContent.getChildAt(1) as FrameLayout).getChildAt(
                            currentStatIndex
                        )
                        nextStat.visibility = View.VISIBLE
                        nextStat.alpha = 0f
                        nextStat.animate()
                            .alpha(1f)
                            .setDuration(300)
                            .start()
                    }
                    .start()

                handler.postDelayed(this, STAT_ROTATION_DELAY)
            }
        }
        handler.postDelayed(statRotationRunnable, STAT_ROTATION_DELAY)
    }

    private fun updateMotivationalMessage() {
        motivationalText.text = contextEngine.getWellnessPrompt()

        motivationalCard.animate()
            .scaleX(1.05f)
            .scaleY(1.05f)
            .setDuration(300)
            .withEndAction {
                motivationalCard.animate()
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(300)
                    .start()
            }
            .start()
    }

    private fun showAIChatDialog() {
        // Create input first
        val input = EditText(this).apply {
            hint = "Share your thoughts, dreams, or feelings..."
            setTextColor(Color.BLACK)
            minLines = 2
        }

        val contextText = TextView(this).apply {
            val timeGreeting = when (Calendar.getInstance().get(Calendar.HOUR_OF_DAY)) {
                in 5..11 -> "Morning vibes ☀️"
                in 12..16 -> "Afternoon flow 🌤"
                in 17..20 -> "Evening energy 🌅"
                else -> "Nighttime dreams 🌙"
            }
            text = "$timeGreeting • 7,542 steps • Last dream: 2 days ago"
            textSize = 14f
            setTextColor(0xFF666666.toInt())
            setPadding(0, 0, 0, 16)
        }

        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
            addView(contextText)
            addView(input)
        }

        // More dynamic greeting
        val greetings = listOf(
            "What's on your mind, dreamer? 🌙",
            "Tell me what's floating through your consciousness... ✨",
            "Share your inner world with me 💭",
            "What dreams may come? Let's explore... 🔮",
            "Your thoughts are safe here. What's surfacing? 🌊"
        )

        speakText(greetings.random())

        AlertDialog.Builder(this)
            .setTitle("🌌 Librium Dreamscape")
            .setView(dialogView)
            .setPositiveButton("Share") { _, _ ->
                val question = input.text.toString()
                if (question.isNotEmpty()) {
                    processAIQuestion(question)
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun processAIQuestion(question: String) {
        val loadingDialog = AlertDialog.Builder(this)
            .setTitle("🌌 Entering the dreamscape...")
            .setMessage("Connecting with your subconscious...")
            .setCancelable(false)
            .create()
        loadingDialog.show()

        lifecycleScope.launch {
            try {
                val context = contextEngine.getCurrentContext()
                val timeOfDay = context["timeOfDay"] as String
                val hour = context["hour"] as Int

                // Check if dream related
                val isDreamRelated = question.toLowerCase().contains("dream") ||
                        hour >= 20 || hour <= 6

                val prompt = """
                    You are Librium, a mystical dream guide and wellness companion with a deep, 
                    intuitive understanding of the human psyche. You speak with wisdom, empathy, 
                    and a touch of ethereal mystery.
                    
                    Current context:
                    - Time: $timeOfDay 
                    - User state: 7,542 steps, active but possibly tired
                    - Last dream entry: 2 days ago
                    - Mood tendency: Seeking connection
                    
                    User says: $question
                    
                    Respond in 2-3 sentences with:
                    - Deep empathy and understanding
                    - A unique insight or perspective
                    - Gentle guidance or thought-provoking question
                    - Use metaphors from nature, dreams, or consciousness
                    - If they mention dreams, be especially mystical
                    
                    Be profound but accessible, like a wise friend who sees beyond the surface.
                """.trimIndent()

                val response = geminiService?.generateResponse(prompt)
                    ?: getDreamscapeResponse(question, isDreamRelated)

                runOnUiThread {
                    loadingDialog.dismiss()
                    showAIResponse(response)
                }

            } catch (e: Exception) {
                runOnUiThread {
                    loadingDialog.dismiss()
                    val fallbackResponse = getDreamscapeResponse(question, false)
                    showAIResponse(fallbackResponse)
                }
            }
        }
    }

    private fun showAIResponse(response: String) {
        // Speak the response
        speakText(response)

        AlertDialog.Builder(this)
            .setTitle("🤖 Librium AI Says:")
            .setMessage(response)
            .setPositiveButton("Thanks!") { _, _ ->
                speakText("You're welcome! Keep up the great work!")
            }
            .setNeutralButton("Ask Another") { _, _ ->
                showAIChatDialog()
            }
            .show()
    }

    private fun enterDreamscape() {
        // Create a dreamy transition dialog
        val dreamDialog = AlertDialog.Builder(this)
            .setTitle("🌌 Entering Dreamscape...")
            .setMessage("Close your eyes. Take a deep breath. Let your mind wander...")
            .setCancelable(false)
            .create()

        dreamDialog.show()

        // Speak the entrance
        speakText("Welcome to your dreamscape. Let your consciousness flow freely.")

        // After 2 seconds, show the AI in dreamscape mode
        Handler(Looper.getMainLooper()).postDelayed({
            dreamDialog.dismiss()
            showDreamscapeAI()
        }, 2000)
    }

    private fun showDreamscapeAI() {
        val dreamView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
            background = GradientDrawable().apply {
                colors = intArrayOf(0xFF1a1a2e.toInt(), 0xFF16213e.toInt(), 0xFF0f3460.toInt())
                orientation = GradientDrawable.Orientation.TOP_BOTTOM
            }
        }

        val promptText = TextView(this).apply {
            text = "In this space, there are no wrong thoughts...\n\nWhat imagery is floating through your mind? 🌊"
            textSize = 18f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        dreamView.addView(promptText)

        val dreamInput = EditText(this).apply {
            hint = "Describe what you see, feel, or imagine..."
            setTextColor(Color.WHITE)
            setHintTextColor(0x80FFFFFF.toInt())
            minLines = 4
            gravity = Gravity.TOP
            background = GradientDrawable().apply {
                setColor(0x20FFFFFF)
                cornerRadius = 16f
            }
            setPadding(16, 16, 16, 16)
        }
        dreamView.addView(dreamInput)

        AlertDialog.Builder(this)
            .setTitle("🌌 Librium Dreamscape")
            .setView(dreamView)
            .setPositiveButton("Journey Deeper") { _, _ ->
                val vision = dreamInput.text.toString()
                if (vision.isNotEmpty()) {
                    processDreamscapeVision(vision)
                }
            }
            .setNegativeButton("Return", null)
            .show()
    }

    private fun processDreamscapeVision(vision: String) {
        lifecycleScope.launch {
            val prompt = """
                You are a dreamscape guide, speaking from within the user's subconscious realm.
                The user has entered a meditative state and shared this vision: "$vision"
                
                Respond as if you ARE part of their dreamscape:
                - Speak in flowing, poetic language
                - Reflect their imagery back with deeper meaning
                - Guide them to self-discovery
                - Use sensory details and metaphors
                - Be mystical but grounding
                
                3-4 sentences that feel like they emerge from within their own mind.
            """.trimIndent()

            val response = geminiService?.generateResponse(prompt)
                ?: "I see the patterns in your vision. Like waves meeting shore, your thoughts seek form. What truth lies beneath these images? 🌊"

            runOnUiThread {
                speakText(response)

                AlertDialog.Builder(this@MainActivity)
                    .setTitle("🌌 From Your Dreamscape")
                    .setMessage(response)
                    .setPositiveButton("Continue Journey") { _, _ ->
                        showDreamscapeAI()
                    }
                    .setNeutralButton("Save Vision") { _, _ ->
                        Toast.makeText(this@MainActivity, "Vision saved to your journal ✨", Toast.LENGTH_LONG).show()
                    }
                    .setNegativeButton("Surface", null)
                    .show()
            }
        }
    }

    private fun getDreamscapeResponse(question: String, isDreamRelated: Boolean): String {
        return if (isDreamRelated) {
            listOf(
                "Dreams are windows to our deeper self. What emotions colored this dream? Let's explore the symbols together. 🌙",
                "The dreamscape holds truths our waking mind can't grasp. Tell me more about what you saw - every detail matters. ✨",
                "Your subconscious is speaking. I sense there's more beneath the surface. What felt most significant? 🔮"
            ).random()
        } else {
            listOf(
                "I feel the weight of what you're carrying. Your journey of 7,542 steps today shows strength. What would lightness feel like? 🌟",
                "Your energy speaks volumes. Sometimes our bodies know truths before our minds catch up. What is your heart telling you? 💫",
                "There's wisdom in your question. Like ripples on water, our thoughts create patterns. What pattern are you ready to change? 🌊"
            ).random()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(statRotationRunnable)
        checkInHandler.removeCallbacks(checkInRunnable)

        // Shutdown Text-to-Speech
        if (::textToSpeech.isInitialized) {
            textToSpeech.stop()
            textToSpeech.shutdown()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                ) {
                    Log.d(TAG, "Notification permission granted")
                }
            }
        }
    }
}
