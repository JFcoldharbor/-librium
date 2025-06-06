package com.example.equilibrium

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.firebase.auth.FirebaseAuth

class MainActivity : AppCompatActivity() {

    private lateinit var auth: FirebaseAuth

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Use your existing layout
        setContentView(R.layout.activity_main)

        // Initialize Firebase Auth
        auth = FirebaseAuth.getInstance()

        // Check if user is already signed in
        val currentUser = auth.currentUser
        if (currentUser != null) {
            navigateToAIAssistant()
            return
        }

        // Make entire screen clickable for testing
        findViewById<android.view.View>(android.R.id.content).setOnClickListener {
            performTestLogin()
        }

        Toast.makeText(this, "Tap anywhere to test login", Toast.LENGTH_LONG).show()
    }

    private fun performTestLogin() {
        Toast.makeText(this, "Testing login...", Toast.LENGTH_SHORT).show()

        auth.signInAnonymously()
            .addOnCompleteListener(this) { task ->
                if (task.isSuccessful) {
                    Toast.makeText(this, "Login successful!", Toast.LENGTH_SHORT).show()
                    navigateToAIAssistant()
                } else {
                    Toast.makeText(this, "Login failed: ${task.exception?.message}", Toast.LENGTH_LONG).show()
                }
            }
    }

    private fun navigateToAIAssistant() {
        Toast.makeText(this, "🎉 LOGIN SUCCESS!", Toast.LENGTH_LONG).show()
        // Navigation temporarily disabled to avoid crashes
    }
}