package com.example.librium

import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import kotlin.math.abs

class MainActivity : AppCompatActivity(), GestureDetector.OnGestureListener {

    // Navigation state
    private var currentHub = 0 // -1 = Life Balance, 0 = Main, 1 = Work
    private lateinit var gestureDetector: GestureDetector
    private lateinit var mainContainer: LinearLayout

    // Simple variables - NO complications!
    private var currentStepCount = 7542
    private var unreadEmails = 3
    private var todayMeetings = 2
    private var balanceScore = 68
    private var currentMood = "😊"
    private var sleepHours = 7.5f

    // Constants for gesture detection
    companion object {
        private const val SWIPE_THRESHOLD = 100
        private const val SWIPE_VELOCITY_THRESHOLD = 100
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize gesture detector
        gestureDetector = GestureDetector(this, this)

        // Create the layout
        createNavigationLayout()
    }

    private fun createNavigationLayout() {
        // Main container that will hold all hubs
        mainContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0F172A"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding(20, 60, 20, 20)

            // Enable touch events for gesture detection
            setOnTouchListener { _, event ->
                gestureDetector.onTouchEvent(event)
                true
            }
        }

        // Load the current hub
        loadCurrentHub()

        setContentView(mainContainer)
    }

    private fun loadCurrentHub() {
        // Clear the container
        mainContainer.removeAllViews()

        when (currentHub) {
            -1 -> createLifeBalanceHub()
            0 -> createMainHub()
            1 -> createWorkHub()
        }

        // Add navigation indicator at the bottom
        addNavigationDots()
    }

    private fun createMainHub() {
        // App title
        val title = TextView(this).apply {
            text = "LIBRIUM"
            textSize = 42f
            setTextColor(Color.parseColor("#FF5722"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }
        mainContainer.addView(title)

        // Greeting
        val greeting = TextView(this).apply {
            text = "Welcome to your wellness journey!"
            textSize = 18f
            setTextColor(Color.parseColor("#94A3B8"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 40)
        }
        mainContainer.addView(greeting)

        // Swipe hint
        val swipeHint = TextView(this).apply {
            text = "← Swipe for Work Hub | Life Balance Hub Swipe →"
            textSize = 12f
            setTextColor(Color.parseColor("#64748B"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }
        mainContainer.addView(swipeHint)

        // Create main cards
        createWellnessCard(mainContainer)
        createWorkCard(mainContainer)
        createCommunicationCard(mainContainer)
    }

    private fun createLifeBalanceHub() {
        // Hub title
        val title = TextView(this).apply {
            text = "✨ LIFE BALANCE"
            textSize = 36f
            setTextColor(Color.parseColor("#8B5CF6"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }
        mainContainer.addView(title)

        // Subtitle
        val subtitle = TextView(this).apply {
            text = "Your holistic wellness dashboard"
            textSize = 16f
            setTextColor(Color.parseColor("#94A3B8"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }
        mainContainer.addView(subtitle)

        // Balance score card
        createBalanceScoreCard(mainContainer)

        // Wellness stats card
        createWellnessStatsCard(mainContainer)

        // Mood tracker card
        createMoodTrackerCard(mainContainer)
    }

    private fun createWorkHub() {
        // Hub title
        val title = TextView(this).apply {
            text = "💼 WORK HUB"
            textSize = 36f
            setTextColor(Color.parseColor("#FF5722"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }
        mainContainer.addView(title)

        // Subtitle
        val subtitle = TextView(this).apply {
            text = "Navigate today's priorities"
            textSize = 16f
            setTextColor(Color.parseColor("#94A3B8"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }
        mainContainer.addView(subtitle)

        // Today's priorities card
        createPrioritiesCard(mainContainer)

        // Quick stats card
        createWorkStatsCard(mainContainer)

        // Goals progress card
        createGoalsCard(mainContainer)
    }

    // ================ MAIN HUB CARDS ================

    private fun createWellnessCard(container: ViewGroup) {
        val card = createStandardCard(container, "#1E293B") {
            try {
                startActivity(Intent(this@MainActivity, WellnessActivity::class.java))
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "Wellness feature coming soon!", Toast.LENGTH_SHORT).show()
            }
        }

        val cardContent = createCardHeader(card, "💪", "Wellness Hub")

        val statsText = TextView(this).apply {
            text = "$currentStepCount steps today • Balance: $balanceScore%"
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8"))
            setPadding(0, 8, 0, 0)
        }
        cardContent.addView(statsText)
    }

    private fun createWorkCard(container: ViewGroup) {
        val card = createStandardCard(container, "#1E293B") {
            Toast.makeText(this@MainActivity, "Work hub - swipe left for full view!", Toast.LENGTH_SHORT).show()
        }

        val cardContent = createCardHeader(card, "💼", "Work Hub")

        val statsText = TextView(this).apply {
            text = "$todayMeetings meetings today • 5 tasks pending"
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8"))
            setPadding(0, 8, 0, 0)
        }
        cardContent.addView(statsText)
    }

    private fun createCommunicationCard(container: ViewGroup) {
        val card = createStandardCard(container, "#1E293B") {
            try {
                startActivity(Intent(this@MainActivity, CommunicationActivity::class.java))
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "Communication feature coming soon!", Toast.LENGTH_SHORT).show()
            }
        }

        val cardContent = createCardHeader(card, "💬", "Communication")

        val statsText = TextView(this).apply {
            text = "$unreadEmails unread messages • Stay connected"
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8"))
            setPadding(0, 8, 0, 0)
        }
        cardContent.addView(statsText)
    }

    // ================ LIFE BALANCE HUB CARDS ================

    private fun createBalanceScoreCard(container: ViewGroup) {
        val card = createStandardCard(container, "#8B5CF6", null)

        val cardContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
            gravity = Gravity.CENTER
        }

        // Big balance score
        val scoreText = TextView(this).apply {
            text = "$balanceScore%"
            textSize = 48f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        cardContent.addView(scoreText)

        val labelText = TextView(this).apply {
            text = "LIFE BALANCE SCORE"
            textSize = 16f
            setTextColor(Color.parseColor("#E2E8F0"))
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 0)
        }
        cardContent.addView(labelText)

        val statusText = TextView(this).apply {
            text = if (balanceScore >= 70) "EXCELLENT" else if (balanceScore >= 50) "GOOD" else "NEEDS ATTENTION"
            textSize = 14f
            setTextColor(if (balanceScore >= 70) Color.parseColor("#10B981") else Color.parseColor("#F59E0B"))
            gravity = Gravity.CENTER
            setPadding(0, 4, 0, 0)
        }
        cardContent.addView(statusText)

        card.addView(cardContent)
    }

    private fun createWellnessStatsCard(container: ViewGroup) {
        val card = createStandardCard(container, "#1E293B", null)

        val cardContent = createCardHeader(card, "📊", "Wellness Stats")

        // Stats grid
        val statsGrid = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 16, 0, 0)
        }

        val stats = listOf(
            Triple("👟", "$currentStepCount", "Steps"),
            Triple("😴", "${sleepHours}h", "Sleep"),
            Triple("💧", "6/8", "Water"),
            Triple("🧘", "15min", "Mindful")
        )

        stats.forEach { (icon, value, label) ->
            val statContainer = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }

            statContainer.addView(TextView(this).apply {
                text = icon
                textSize = 24f
                gravity = Gravity.CENTER
            })

            statContainer.addView(TextView(this).apply {
                text = value
                textSize = 18f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                setPadding(0, 4, 0, 2)
            })

            statContainer.addView(TextView(this).apply {
                text = label
                textSize = 12f
                setTextColor(Color.parseColor("#94A3B8"))
                gravity = Gravity.CENTER
            })

            statsGrid.addView(statContainer)
        }

        cardContent.addView(statsGrid)
    }

    private fun createMoodTrackerCard(container: ViewGroup) {
        val card = createStandardCard(container, "#1E293B", null)

        val cardContent = createCardHeader(card, "😊", "Today's Mood")

        val moodText = TextView(this).apply {
            text = "Current mood: $currentMood"
            textSize = 16f
            setTextColor(Color.WHITE)
            setPadding(0, 8, 0, 8)
        }
        cardContent.addView(moodText)

        val moodRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 0)
        }

        val moods = listOf("😔", "😐", "😊", "😄", "🤩")
        moods.forEach { mood ->
            val moodButton = TextView(this).apply {
                text = mood
                textSize = 28f
                setPadding(12, 8, 12, 8)
                if (mood == currentMood) {
                    setBackgroundColor(Color.parseColor("#8B5CF6"))
                }
                setOnClickListener {
                    currentMood = mood
                    loadCurrentHub() // Refresh to show updated mood
                    Toast.makeText(this@MainActivity, "Mood updated to $mood", Toast.LENGTH_SHORT).show()
                }
            }
            moodRow.addView(moodButton)
        }

        cardContent.addView(moodRow)
    }

    // ================ WORK HUB CARDS ================

    private fun createPrioritiesCard(container: ViewGroup) {
        val card = createStandardCard(container, "#FF5722", null)

        val cardContent = createCardHeader(card, "🎯", "Today's Priorities")

        val priorities = listOf(
            "Call back Sarah Miller - Urgent",
            "Review Q4 Budget Report",
            "Prepare client presentation",
            "Team sync at 3:00 PM"
        )

        priorities.forEach { priority ->
            val priorityText = TextView(this).apply {
                text = "• $priority"
                textSize = 14f
                setTextColor(Color.WHITE)
                setPadding(0, 4, 0, 4)
            }
            cardContent.addView(priorityText)
        }
    }

    private fun createWorkStatsCard(container: ViewGroup) {
        val card = createStandardCard(container, "#1E293B", null)

        val cardContent = createCardHeader(card, "📈", "Quick Stats")

        val statsGrid = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 16, 0, 0)
        }

        val workStats = listOf(
            Triple("📋", "8", "Tasks"),
            Triple("📅", "$todayMeetings", "Meetings"),
            Triple("📧", "$unreadEmails", "Emails"),
            Triple("⏰", "6h", "Focus Time")
        )

        workStats.forEach { (icon, value, label) ->
            val statContainer = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }

            statContainer.addView(TextView(this).apply {
                text = icon
                textSize = 20f
                gravity = Gravity.CENTER
            })

            statContainer.addView(TextView(this).apply {
                text = value
                textSize = 18f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                setPadding(0, 4, 0, 2)
            })

            statContainer.addView(TextView(this).apply {
                text = label
                textSize = 12f
                setTextColor(Color.parseColor("#94A3B8"))
                gravity = Gravity.CENTER
            })

            statsGrid.addView(statContainer)
        }

        cardContent.addView(statsGrid)
    }

    private fun createGoalsCard(container: ViewGroup) {
        val card = createStandardCard(container, "#1E293B", null)

        val cardContent = createCardHeader(card, "🏆", "Q4 Goals Progress")

        val goals = listOf(
            Pair("Revenue Target", 78),
            Pair("Client Acquisition", 85),
            Pair("Team Growth", 65)
        )

        goals.forEach { (goal, progress) ->
            val goalContainer = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(0, 8, 0, 8)
            }

            val goalHeader = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
            }

            goalHeader.addView(TextView(this).apply {
                text = goal
                textSize = 14f
                setTextColor(Color.WHITE)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            })

            goalHeader.addView(TextView(this).apply {
                text = "$progress%"
                textSize = 14f
                setTextColor(Color.parseColor("#10B981"))
                typeface = Typeface.DEFAULT_BOLD
            })

            goalContainer.addView(goalHeader)

            // Simple progress indicator
            val progressBar = View(this).apply {
                setBackgroundColor(Color.parseColor("#10B981"))
                layoutParams = LinearLayout.LayoutParams(
                    (resources.displayMetrics.widthPixels * progress / 100 * 0.8).toInt(),
                    8
                ).apply {
                    topMargin = 4
                }
            }
            goalContainer.addView(progressBar)

            cardContent.addView(goalContainer)
        }
    }

    // ================ HELPER METHODS ================

    private fun createStandardCard(container: ViewGroup, backgroundColor: String, onClick: (() -> Unit)?): CardView {
        val card = CardView(this).apply {
            radius = 16f
            cardElevation = 8f
            setCardBackgroundColor(Color.parseColor(backgroundColor))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 20
            }
            onClick?.let { setOnClickListener { it() } }
        }
        container.addView(card)
        return card
    }

    private fun createCardHeader(card: CardView, icon: String, title: String): LinearLayout {
        val cardContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        header.addView(TextView(this).apply {
            text = icon
            textSize = 28f
            setPadding(0, 0, 16, 0)
        })

        header.addView(TextView(this).apply {
            text = title
            textSize = 18f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
        })

        cardContent.addView(header)
        card.addView(cardContent)
        return cardContent
    }

    private fun addNavigationDots() {
        val dotsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, 20, 0, 0)
        }

        for (i in -1..1) {
            val dot = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(if (i == currentHub) Color.parseColor("#FF5722") else Color.parseColor("#64748B"))
                }
                layoutParams = LinearLayout.LayoutParams(
                    if (i == currentHub) 24 else 12,
                    12
                ).apply {
                    setMargins(6, 0, 6, 0)
                }
            }
            dotsContainer.addView(dot)
        }

        mainContainer.addView(dotsContainer)
    }

    // ================ GESTURE HANDLING ================

    override fun onTouchEvent(event: MotionEvent): Boolean {
        return gestureDetector.onTouchEvent(event) || super.onTouchEvent(event)
    }

    override fun onDown(e: MotionEvent): Boolean = true
    override fun onShowPress(e: MotionEvent) {}
    override fun onSingleTapUp(e: MotionEvent): Boolean = false
    override fun onScroll(e1: MotionEvent?, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean = false
    override fun onLongPress(e: MotionEvent) {}

    override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
        if (e1 == null) return false

        val diffX = e2.x - e1.x

        if (abs(diffX) > SWIPE_THRESHOLD && abs(velocityX) > SWIPE_VELOCITY_THRESHOLD) {
            if (diffX > 0) {
                // Swipe right - go to previous hub
                if (currentHub > -1) {
                    currentHub--
                    loadCurrentHub()
                    Toast.makeText(this, getHubName(), Toast.LENGTH_SHORT).show()
                }
            } else {
                // Swipe left - go to next hub
                if (currentHub < 1) {
                    currentHub++
                    loadCurrentHub()
                    Toast.makeText(this, getHubName(), Toast.LENGTH_SHORT).show()
                }
            }
            return true
        }
        return false
    }

    private fun getHubName(): String {
        return when (currentHub) {
            -1 -> "Life Balance Hub"
            0 -> "Main Hub"
            1 -> "Work Hub"
            else -> "Unknown Hub"
        }
    }

    override fun onBackPressed() {
        if (currentHub != 0) {
            currentHub = 0
            loadCurrentHub()
        } else {
            super.onBackPressed()
        }
    }
}