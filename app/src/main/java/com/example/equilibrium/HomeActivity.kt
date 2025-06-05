package com.example.equilibrium

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.TextView
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.material.floatingactionbutton.FloatingActionButton

class HomeActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Hide the action bar
        supportActionBar?.hide()

        enableEdgeToEdge()
        setContentView(R.layout.activity_home)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        // Set up FAB
        val fabAI = findViewById<FloatingActionButton>(R.id.fabAI)
        fabAI.setOnClickListener {
            Toast.makeText(this, "AI Assistant coming soon!", Toast.LENGTH_SHORT).show()

            // In HomeActivity.kt, update the FAB click listener:
            val fabAI = findViewById<FloatingActionButton>(R.id.fabAI)
            fabAI.setOnClickListener {
                val intent = Intent(this, AIAssistantActivity::class.java)
                startActivity(intent)
                // In HomeActivity.kt, add this to the onCreate method after setContentView:

// Get the AI assistant name
                val sharedPrefs = getSharedPreferences("EquilibriumPrefs", Context.MODE_PRIVATE)
                val assistantName = sharedPrefs.getString("assistant_name", "AI Assistant") ?: "AI Assistant"

// Update the AI insight text to include the assistant name
                val aiInsightText = findViewById<TextView>(R.id.aiInsightText)
                if (aiInsightText != null) {
                    val insights = listOf(
                        "$assistantName says: Great job staying active today! Your step count is 15% above your daily average.",
                        "$assistantName's tip: Time for a hydration break! You're 2 glasses behind your daily goal.",
                        "$assistantName reminds you: You have a team meeting in 30 minutes. Perfect time for a quick stretch!",
                        "$assistantName suggests: Your productivity peaks at 10 AM. Schedule important tasks for tomorrow morning."
                    )
                    aiInsightText.text = insights.random()
                }
            }
        }

        // Animate FAB
        fabAI.scaleX = 0f
        fabAI.scaleY = 0f
        fabAI.animate()
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(500)
            .setStartDelay(300)
            .start()

        // NEW: Make cards clickable
        setupClickableCards()
    }

    private fun setupClickableCards() {
        // Steps Card
        val stepsCard = findViewById<CardView>(R.id.cardSteps)
        stepsCard.setOnClickListener {
            val intent = Intent(this, StepDetailsActivity::class.java)
            startActivity(intent)
        }

        // Calories Card
        findViewById<CardView>(R.id.cardCalories).setOnClickListener {
            Toast.makeText(this, "Calories tracking coming soon!", Toast.LENGTH_SHORT).show()
        }

        // Hydration Card
        findViewById<CardView>(R.id.cardHydration).setOnClickListener {
            Toast.makeText(this, "Hydration tracking coming soon!", Toast.LENGTH_SHORT).show()
        }

        // Texts Card
        findViewById<CardView>(R.id.cardTexts).setOnClickListener {
            Toast.makeText(this, "Messages coming soon!", Toast.LENGTH_SHORT).show()
        }

        // Emails Card
        findViewById<CardView>(R.id.cardEmails).setOnClickListener {
            Toast.makeText(this, "Emails coming soon!", Toast.LENGTH_SHORT).show()
        }

        // Workout Card
        findViewById<CardView>(R.id.cardWorkout).setOnClickListener {
            Toast.makeText(this, "Workout tracking coming soon!", Toast.LENGTH_SHORT).show()
        }

        // Meals Card
        findViewById<CardView>(R.id.cardMeals).setOnClickListener {
            Toast.makeText(this, "Meal planning coming soon!", Toast.LENGTH_SHORT).show()
        }

        // Financial Card
        findViewById<CardView>(R.id.cardFinancial).setOnClickListener {
            Toast.makeText(this, "Financial tracking coming soon!", Toast.LENGTH_SHORT).show()
        }
    }
}
