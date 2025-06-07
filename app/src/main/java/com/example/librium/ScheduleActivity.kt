package com.example.librium

import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import java.text.SimpleDateFormat
import java.util.*

class ScheduleActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF0F172A.toInt())
            setPadding(24, 24, 24, 24)
        }

        // Header
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
            text = "📅 Schedule"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(16, 0, 0, 0)
        }
        header.addView(title)

        mainLayout.addView(header)

        // Today's date
        val dateFormat = SimpleDateFormat("EEEE, MMMM d", Locale.getDefault())
        mainLayout.addView(TextView(this).apply {
            text = dateFormat.format(Date())
            textSize = 18f
            setTextColor(0xFFFF5722.toInt())
            setPadding(0, 0, 0, 16)
        })

        // Schedule items
        val schedule = listOf(
            Triple("9:00 AM", "Team Standup", "Daily sync with the team"),
            Triple("10:30 AM", "Code Review", "Review pull requests"),
            Triple("12:00 PM", "Lunch Break", "Time to recharge"),
            Triple("2:00 PM", "Client Meeting", "Project status update"),
            Triple("3:30 PM", "Focus Time", "Deep work - no meetings"),
            Triple("5:00 PM", "Wrap Up", "Review today's progress")
        )

        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        schedule.forEach { (time, title, description) ->
            val meetingCard = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setBackgroundColor(0xFF1E293B.toInt())
                setPadding(20, 20, 20, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(0, 0, 0, 16)
                }
            }

            // Time column
            val timeText = TextView(this).apply {
                text = time
                textSize = 14f
                setTextColor(Color.WHITE)
                setBackgroundColor(0xFF9C27B0.toInt())
                setPadding(16, 8, 16, 8)
                gravity = Gravity.CENTER
            }
            meetingCard.addView(timeText)

            // Details column
            val detailsLayout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(16, 0, 0, 0)
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                )
            }

            detailsLayout.addView(TextView(this).apply {
                text = title
                textSize = 18f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
            })

            detailsLayout.addView(TextView(this).apply {
                text = description
                textSize = 14f
                setTextColor(0xFF94A3B8.toInt())
                setPadding(0, 4, 0, 0)
            })

            meetingCard.addView(detailsLayout)
            mainLayout.addView(meetingCard)
        }

        val scrollView = ScrollView(this).apply {
            addView(mainLayout)
        }

        setContentView(scrollView)
    }
}