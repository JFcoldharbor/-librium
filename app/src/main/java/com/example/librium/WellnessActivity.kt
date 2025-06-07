package com.example.librium

import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity

class WellnessActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Simple layout
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF0F172A.toInt())
            setPadding(24, 24, 24, 24)
        }

        // Header with back button
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 24)
        }

        val backButton = Button(this).apply {
            text = "← Back"
            setOnClickListener { finish() }
        }
        header.addView(backButton)

        val title = TextView(this).apply {
            text = "Wellness Dashboard"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(16, 0, 0, 0)
        }
        header.addView(title)

        mainLayout.addView(header)

        // Wellness Stats
        val stats = listOf(
            Triple("👟 Steps Today", "7,542", "Goal: 10,000"),
            Triple("🔥 Calories Burned", "1,850", "Goal: 2,000"),
            Triple("❤️ Avg Heart Rate", "72 bpm", "Resting: 65 bpm"),
            Triple("💧 Water Intake", "5 glasses", "Goal: 8 glasses"),
            Triple("😴 Sleep Last Night", "7.5 hours", "Quality: Good"),
            Triple("🧘 Mindfulness", "15 minutes", "Streak: 5 days")
        )

        stats.forEach { (label, value, subtext) ->
            val statCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(0xFF1E293B.toInt())
                setPadding(20, 20, 20, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(0, 0, 0, 16)
                }
            }

            statCard.addView(TextView(this).apply {
                text = label
                textSize = 16f
                setTextColor(0xFF94A3B8.toInt())
            })

            statCard.addView(TextView(this).apply {
                text = value
                textSize = 28f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
                setPadding(0, 8, 0, 8)
            })

            statCard.addView(TextView(this).apply {
                text = subtext
                textSize = 14f
                setTextColor(0xFF64748B.toInt())
            })

            mainLayout.addView(statCard)
        }

        val scrollView = ScrollView(this).apply {
            addView(mainLayout)
        }

        setContentView(scrollView)
    }
}