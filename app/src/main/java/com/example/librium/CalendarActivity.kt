package com.example.librium

import android.app.AlertDialog
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import java.text.SimpleDateFormat
import java.util.*

class CalendarActivity : AppCompatActivity() {

    private lateinit var selectedDateText: TextView
    private lateinit var eventsContainer: LinearLayout
    private val dateFormat = SimpleDateFormat("EEEE, MMMM d, yyyy", Locale.getDefault())
    private var selectedDate = Calendar.getInstance()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create main layout
        val scrollView = ScrollView(this)
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
        }

        // Add title
        val titleText = TextView(this).apply {
            text = "Calendar"
            textSize = 28f
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 24)
        }
        mainLayout.addView(titleText)

        // Calendar navigation
        val navLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER_VERTICAL

            val prevButton = Button(this@CalendarActivity).apply {
                text = "◀"
                setOnClickListener { navigateDate(-1) }
            }

            selectedDateText = TextView(this@CalendarActivity).apply {
                text = dateFormat.format(selectedDate.time)
                textSize = 18f
                setPadding(16, 0, 16, 0)
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                )
                gravity = android.view.Gravity.CENTER
            }

            val nextButton = Button(this@CalendarActivity).apply {
                text = "▶"
                setOnClickListener { navigateDate(1) }
            }

            val todayButton = Button(this@CalendarActivity).apply {
                text = "Today"
                setOnClickListener {
                    selectedDate = Calendar.getInstance()
                    updateDisplay()
                }
            }

            addView(prevButton)
            addView(selectedDateText)
            addView(nextButton)
            addView(todayButton)
        }
        mainLayout.addView(navLayout)

        // Events container
        eventsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 24, 0, 0)
        }
        mainLayout.addView(eventsContainer)

        // Add event button
        val addEventButton = Button(this).apply {
            text = "➕ Add Event"
            setOnClickListener { showAddEventDialog() }
        }
        mainLayout.addView(addEventButton)

        // Back button
        val backButton = Button(this).apply {
            text = "← Back"
            setOnClickListener { finish() }
        }
        mainLayout.addView(backButton)

        scrollView.addView(mainLayout)
        setContentView(scrollView)

        // Load initial events
        updateDisplay()
    }

    private fun navigateDate(days: Int) {
        selectedDate.add(Calendar.DAY_OF_MONTH, days)
        updateDisplay()
    }

    private fun updateDisplay() {
        selectedDateText.text = dateFormat.format(selectedDate.time)
        loadEventsForDate()
    }

    private fun loadEventsForDate() {
        eventsContainer.removeAllViews()

        // Sample events (in a real app, these would come from a database)
        val events = getSampleEvents()

        if (events.isEmpty()) {
            val noEventsText = TextView(this).apply {
                text = "No events scheduled"
                textSize = 16f
                setTextColor(Color.GRAY)
                setPadding(0, 16, 0, 16)
            }
            eventsContainer.addView(noEventsText)
        } else {
            events.forEach { event ->
                addEventCard(event)
            }
        }
    }

    private fun getSampleEvents(): List<EventData> {
        val dayOfWeek = selectedDate.get(Calendar.DAY_OF_WEEK)
        val dayOfMonth = selectedDate.get(Calendar.DAY_OF_MONTH)

        return when {
            dayOfWeek == Calendar.MONDAY -> listOf(
                EventData("Team Meeting", "10:00 AM - 11:00 AM", "Conference Room A", "#2196F3"),
                EventData("Lunch with Sarah", "12:30 PM - 1:30 PM", "Cafe Downtown", "#4CAF50")
            )
            dayOfWeek == Calendar.WEDNESDAY -> listOf(
                EventData("Yoga Class", "6:00 PM - 7:00 PM", "Wellness Center", "#9C27B0"),
                EventData("Project Deadline", "5:00 PM", "Submit Q4 Report", "#F44336")
            )
            dayOfMonth == 8 -> listOf(
                EventData("Sarah's Birthday! 🎂", "All Day", "Don't forget gift!", "#E91E63")
            )
            else -> emptyList()
        }
    }

    private fun addEventCard(event: EventData) {
        val card = CardView(this).apply {
            radius = 12f
            cardElevation = 4f
            setCardBackgroundColor(Color.WHITE)

            val content = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(16, 16, 16, 16)

                // Color indicator
                val colorIndicator = View(context).apply {
                    layoutParams = LinearLayout.LayoutParams(8, LinearLayout.LayoutParams.MATCH_PARENT)
                    setBackgroundColor(Color.parseColor(event.color))
                }

                // Event details
                val detailsLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(16, 0, 0, 0)

                    val titleText = TextView(context).apply {
                        text = event.title
                        textSize = 18f
                        setTextColor(Color.BLACK)
                    }

                    val timeText = TextView(context).apply {
                        text = event.time
                        textSize = 14f
                        setTextColor(Color.GRAY)
                    }

                    val locationText = TextView(context).apply {
                        text = event.location
                        textSize = 14f
                        setTextColor(Color.GRAY)
                    }

                    addView(titleText)
                    addView(timeText)
                    addView(locationText)
                }

                addView(colorIndicator)
                addView(detailsLayout)
            }

            addView(content)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 12)
            }
        }

        eventsContainer.addView(card)
    }

    private fun showAddEventDialog() {
        val dialogLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)

            val titleInput = EditText(context).apply {
                hint = "Event title"
            }

            val timeInput = EditText(context).apply {
                hint = "Time (e.g., 2:00 PM)"
            }

            val locationInput = EditText(context).apply {
                hint = "Location"
            }

            addView(titleInput)
            addView(timeInput)
            addView(locationInput)
        }

        AlertDialog.Builder(this)
            .setTitle("New Event")
            .setView(dialogLayout)
            .setPositiveButton("Add") { _, _ ->
                val title = (dialogLayout.getChildAt(0) as EditText).text.toString()
                val time = (dialogLayout.getChildAt(1) as EditText).text.toString()
                val location = (dialogLayout.getChildAt(2) as EditText).text.toString()

                if (title.isNotEmpty()) {
                    addEventCard(EventData(title, time, location, "#FF9800"))
                    Toast.makeText(this, "Event added!", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    data class EventData(val title: String, val time: String, val location: String, val color: String)
}