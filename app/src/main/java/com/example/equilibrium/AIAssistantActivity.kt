package com.example.equilibrium

import android.animation.ValueAnimator
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.view.animation.LinearInterpolator
import android.widget.EditText
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import com.google.android.material.floatingactionbutton.FloatingActionButton

class AIAssistantActivity : AppCompatActivity() {

    private lateinit var glowView: View
    private lateinit var micButton: FloatingActionButton
    private lateinit var statusText: TextView
    private lateinit var responseCard: CardView
    private lateinit var responseText: TextView
    private lateinit var waveformView: ImageView
    private lateinit var titleText: TextView
    private lateinit var editNameButton: ImageView

    private var isListening = false
    private var glowAnimator: ValueAnimator? = null
    private lateinit var sharedPrefs: SharedPreferences
    private var assistantName = "AI Assistant"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Hide the action bar for full screen experience
        supportActionBar?.hide()

        setContentView(R.layout.activity_ai_assistant)

        // Initialize SharedPreferences
        sharedPrefs = getSharedPreferences("EquilibriumPrefs", Context.MODE_PRIVATE)
        assistantName = sharedPrefs.getString("assistant_name", "AI Assistant") ?: "AI Assistant"

        // Initialize views
        initializeViews()

        // Set the assistant name
        titleText.text = assistantName

        // Set up the back button
        findViewById<ImageView>(R.id.backButton).setOnClickListener {
            finish()
        }

        // Set up edit name button
        editNameButton.setOnClickListener {
            showEditNameDialog()
        }

        // Set up microphone button
        micButton.setOnClickListener {
            toggleListening()
        }

        // Start the glow animation
        startGlowAnimation()
    }

    private fun initializeViews() {
        glowView = findViewById(R.id.glowEffect)
        micButton = findViewById(R.id.micButton)
        statusText = findViewById(R.id.statusText)
        responseCard = findViewById(R.id.responseCard)
        responseText = findViewById(R.id.responseText)
        waveformView = findViewById(R.id.waveformView)
        titleText = findViewById(R.id.titleText)
        editNameButton = findViewById(R.id.editNameButton)
    }

    private fun showEditNameDialog() {
        val editText = EditText(this).apply {
            setText(assistantName)
            setTextColor(resources.getColor(android.R.color.black, null))
            hint = "Enter assistant name"
        }

        AlertDialog.Builder(this)
            .setTitle("Name Your Assistant")
            .setMessage("Give your AI assistant a personalized name")
            .setView(editText)
            .setPositiveButton("Save") { _, _ ->
                val newName = editText.text.toString().trim()
                if (newName.isNotEmpty()) {
                    assistantName = newName
                    titleText.text = assistantName

                    // Save to SharedPreferences
                    sharedPrefs.edit().putString("assistant_name", assistantName).apply()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun toggleListening() {
        isListening = !isListening

        if (isListening) {
            // Start listening
            statusText.text = "Listening..."
            micButton.setImageResource(android.R.drawable.ic_media_pause)
            waveformView.visibility = View.VISIBLE
            responseCard.visibility = View.GONE

            // Simulate waveform animation
            animateWaveform()

            // Simulate AI response after 3 seconds
            micButton.postDelayed({
                if (isListening) {
                    stopListening()
                    showAIResponse()
                }
            }, 3000)
        } else {
            stopListening()
        }
    }

    private fun stopListening() {
        isListening = false
        statusText.text = "Tap to speak"
        micButton.setImageResource(android.R.drawable.ic_btn_speak_now)
        waveformView.visibility = View.GONE
        waveformView.animate().cancel()
    }

    private fun showAIResponse() {
        statusText.text = "Here's what I found"
        responseCard.visibility = View.VISIBLE

        // Use the custom name in responses
        val responses = listOf(
            "Hi! I'm $assistantName. Based on your activity today, you've been doing great! You've completed 6,234 steps and stayed well-hydrated. Consider taking a short break to stretch - it's been 2 hours since your last movement.",
            "Hello! $assistantName here. I noticed you've been very productive today! Your step count is above average, and your hydration is on track. How about a 5-minute mindfulness break?",
            "Hey there! It's $assistantName. You're crushing your fitness goals today! Keep up the great work. Remember to take a moment to celebrate your progress.",
            "$assistantName at your service! Your wellness metrics look fantastic today. You're maintaining great balance between activity and rest."
        )

        responseText.text = responses.random()

        // Animate response card
        responseCard.alpha = 0f
        responseCard.translationY = 50f
        responseCard.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(500)
            .start()
    }

    private fun animateWaveform() {
        waveformView.animate()
            .scaleY(1.2f)
            .setDuration(200)
            .withEndAction {
                waveformView.animate()
                    .scaleY(0.8f)
                    .setDuration(200)
                    .withEndAction {
                        if (isListening) {
                            animateWaveform()
                        }
                    }
                    .start()
            }
            .start()
    }

    private fun startGlowAnimation() {
        glowAnimator = ValueAnimator.ofFloat(0.6f, 1f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = LinearInterpolator()

            addUpdateListener { animator ->
                val value = animator.animatedValue as Float
                glowView.alpha = value
                glowView.scaleX = 1f + (value - 0.6f) * 0.1f
                glowView.scaleY = 1f + (value - 0.6f) * 0.1f
            }

            start()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        glowAnimator?.cancel()
    }
}