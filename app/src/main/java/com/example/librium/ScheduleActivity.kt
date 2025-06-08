package com.example.librium

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import java.text.SimpleDateFormat
import java.util.*

class ScheduleActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0F172A"))
            setPadding(24, 24, 24, 24)
        }

        // Header
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 40, 0, 24)
        }

        val backButton = Button(this).apply {
            text = "← Back"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { finish() }
        }

        val title = TextView(this).apply {
            text = "📅 Today's Schedule"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(16, 0, 0, 0)
        }

        header.addView(backButton)
        header.addView(title)
        mainLayout.addView(header)

        // Current time card
        val timeCard = CardView(this).apply {
            radius = 20f
            setCardBackgroundColor(Color.parseColor("#1E293B"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 20
            }
        }

        val timeContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 20, 20, 20)
            gravity = Gravity.CENTER
        }

        val currentTime = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date())
        val currentDate = SimpleDateFormat("EEEE, MMMM d", Locale.getDefault()).format(Date())

        timeContent.addView(TextView(this).apply {
            text = currentTime
            textSize = 36f
            setTextColor(Color.parseColor("#FF5722"))
            typeface = Typeface.DEFAULT_BOLD
        })

        timeContent.addView(TextView(this).apply {
            text = currentDate
            textSize = 18f
            setTextColor(Color.parseColor("#94A3B8"))
        })

        timeCard.addView(timeContent)
        mainLayout.addView(timeCard)

        // Schedule items
        val events = listOf(
            Triple("9:00 AM", "Morning Standup", "Team sync - 15 min"),
            Triple("10:00 AM", "Q4 Budget Review", "Finance meeting - 1 hour"),
            Triple("12:00 PM", "Lunch Break", "Wellness time"),
            Triple("2:00 PM", "Client Presentation", "Project demo - 45 min"),
            Triple("4:00 PM", "Team Sync", "Weekly review - 30 min"),
            Triple("5:30 PM", "Wrap Up", "End of day tasks")
        )

        events.forEach { (time, title, description) ->
            val eventCard = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setBackgroundColor(Color.parseColor("#1E293B"))
                setPadding(20, 20, 20, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = 12
                }
            }

            val timeText = TextView(this).apply {
                text = time
                textSize = 16f
                setTextColor(Color.parseColor("#FF5722"))
                typeface = Typeface.DEFAULT_BOLD
                layoutParams = LinearLayout.LayoutParams(120, LinearLayout.LayoutParams.WRAP_CONTENT)
            }

            val eventInfo = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                )
            }

            eventInfo.addView(TextView(this).apply {
                text = title
                textSize = 18f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
            })

            eventInfo.addView(TextView(this).apply {
                text = description
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
            })

            eventCard.addView(timeText)
            eventCard.addView(eventInfo)
            mainLayout.addView(eventCard)
        }

        val scrollView = ScrollView(this).apply {
            addView(mainLayout)
        }

        setContentView(scrollView)
    }
}