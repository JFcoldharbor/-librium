package com.example.equilibrium

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView

class HomeActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_home)

        // Get the AI assistant name
        val sharedPrefs = getSharedPreferences("EquilibriumPrefs", Context.MODE_PRIVATE)
        val assistantName = sharedPrefs.getString("assistant_name", "AI Assistant") ?: "AI Assistant"

        // Update the AI insight text
        val aiInsightText = findViewById<TextView>(R.id.aiInsightText)
        aiInsightText?.text = "$assistantName says: Welcome to Equilibrium! Your AI-first wellness assistant is ready!"

        setupClickableCards()
    }

    private fun setupClickableCards() {
        // All cards just show "coming soon" messages for now

        findViewById<CardView>(R.id.cardSteps)?.setOnClickListener {
            Toast.makeText(this, "Steps feature coming soon! Use the AI Assistant instead!", Toast.LENGTH_SHORT).show()
        }

        findViewById<CardView>(R.id.cardCalories)?.setOnClickListener {
            Toast.makeText(this, "Calories tracking coming soon! Ask the AI Assistant!", Toast.LENGTH_SHORT).show()
        }

        findViewById<CardView>(R.id.cardTexts)?.setOnClickListener {
            Toast.makeText(this, "Text messaging coming soon! Try the AI Assistant!", Toast.LENGTH_SHORT).show()
        }

        findViewById<CardView>(R.id.cardEmails)?.setOnClickListener {
            Toast.makeText(this, "Email integration coming soon! Ask the AI Assistant!", Toast.LENGTH_SHORT).show()
        }

        findViewById<CardView>(R.id.cardHydration)?.setOnClickListener {
            Toast.makeText(this, "Hydration tracking coming soon! Ask the AI Assistant!", Toast.LENGTH_SHORT).show()
        }

        findViewById<CardView>(R.id.cardWorkout)?.setOnClickListener {
            Toast.makeText(this, "Workout tracking coming soon! Ask the AI Assistant!", Toast.LENGTH_SHORT).show()
        }

        findViewById<CardView>(R.id.cardMeals)?.setOnClickListener {
            Toast.makeText(this, "Meal planning coming soon! Ask the AI Assistant!", Toast.LENGTH_SHORT).show()
        }

        findViewById<CardView>(R.id.cardFinancial)?.setOnClickListener {
            Toast.makeText(this, "Financial features coming soon! Ask the AI Assistant!", Toast.LENGTH_SHORT).show()
        }
    }
}