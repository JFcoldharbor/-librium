package com.example.librium

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import java.util.*

class RemindersActivity : AppCompatActivity() {

    private lateinit var remindersList: LinearLayout
    private val CHANNEL_ID = "EquilibriumReminders"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        createNotificationChannel()

        // Create main layout
        val scrollView = ScrollView(this)
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
        }

        // Add title
        val titleText = TextView(this).apply {
            text = "Reminders & Notifications"
            textSize = 28f
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 24)
        }
        mainLayout.addView(titleText)

        // Add new reminder button
        val addReminderButton = Button(this).apply {
            text = "➕ Add New Reminder"
            setOnClickListener { showAddReminderDialog() }
        }
        mainLayout.addView(addReminderButton)

        // Reminders list container
        remindersList = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 16, 0, 0)
        }
        mainLayout.addView(remindersList)

        // Add sample reminders
        addSampleReminders()

        // Add back button
        val backButton = Button(this).apply {
            text = "← Back"
            setOnClickListener { finish() }
        }
        mainLayout.addView(backButton)

        scrollView.addView(mainLayout)
        setContentView(scrollView)
    }

    private fun addSampleReminders() {
        val sampleReminders = listOf(
            ReminderData("💊 Take vitamins", "Daily at 8:00 AM", true),
            ReminderData("🎂 Sarah's Birthday", "Dec 8, 2024", true),
            ReminderData("💼 Team Meeting", "Every Monday 10:00 AM", true),
            ReminderData("🏃 Exercise Break", "Daily at 3:00 PM", false),
            ReminderData("💧 Drink Water", "Every 2 hours", true)
        )

        sampleReminders.forEach { reminder ->
            addReminderCard(reminder)
        }
    }

    private fun addReminderCard(reminder: ReminderData) {
        val card = CardView(this).apply {
            radius = 12f
            cardElevation = 4f
            setCardBackgroundColor(Color.WHITE)

            val content = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(16, 16, 16, 16)
                gravity = android.view.Gravity.CENTER_VERTICAL

                // Reminder info
                val infoLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(
                        0,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        1f
                    )

                    val titleText = TextView(context).apply {
                        text = reminder.title
                        textSize = 18f
                        setTextColor(Color.BLACK)
                    }

                    val timeText = TextView(context).apply {
                        text = reminder.time
                        textSize = 14f
                        setTextColor(Color.GRAY)
                    }

                    addView(titleText)
                    addView(timeText)
                }

                // Toggle switch
                val toggleSwitch = Switch(context).apply {
                    isChecked = reminder.isEnabled
                    setOnCheckedChangeListener { _, isChecked ->
                        if (isChecked) {
                            scheduleNotification(reminder.title, reminder.time)
                            Toast.makeText(context, "Reminder enabled", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(context, "Reminder disabled", Toast.LENGTH_SHORT).show()
                        }
                    }
                }

                addView(infoLayout)
                addView(toggleSwitch)
            }

            addView(content)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 12)
            }
        }

        remindersList.addView(card)
    }

    private fun showAddReminderDialog() {
        val dialogLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)

            val titleInput = EditText(context).apply {
                hint = "Reminder title"
            }

            val timeInput = EditText(context).apply {
                hint = "Time (e.g., Daily at 9:00 AM)"
            }

            addView(titleInput)
            addView(timeInput)
        }

        AlertDialog.Builder(this)
            .setTitle("New Reminder")
            .setView(dialogLayout)
            .setPositiveButton("Add") { _, _ ->
                val title = (dialogLayout.getChildAt(0) as EditText).text.toString()
                val time = (dialogLayout.getChildAt(1) as EditText).text.toString()

                if (title.isNotEmpty() && time.isNotEmpty()) {
                    addReminderCard(ReminderData("🔔 $title", time, true))
                    scheduleNotification(title, time)
                    Toast.makeText(this, "Reminder added!", Toast.LENGTH_SHORT).show()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Equilibrium Reminders"
            val descriptionText = "Reminders for work-life balance"
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun scheduleNotification(title: String, time: String) {
        // In a real app, you would parse the time and schedule actual notifications
        // For now, just show a toast
        Toast.makeText(this, "Scheduled: $title at $time", Toast.LENGTH_SHORT).show()
    }

    data class ReminderData(val title: String, val time: String, val isEnabled: Boolean)
}