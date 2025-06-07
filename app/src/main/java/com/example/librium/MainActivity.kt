package com.example.librium

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import com.example.librium.databinding.ActivityMainBinding
import com.google.firebase.auth.FirebaseAuth

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var auth: FirebaseAuth

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set up immersive mode
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Initialize Firebase Auth
        auth = FirebaseAuth.getInstance()

        // TEMPORARY: Auto sign-in anonymously and go to AI
        autoSignInAndNavigate()

        // Keep buttons for future use but disabled
        binding.googleSignInButton.isEnabled = false
        binding.anonymousLoginButton.isEnabled = false
    }

    private fun autoSignInAndNavigate() {
        // Sign in anonymously in background
        auth.signInAnonymously()
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    // Go directly to AI Assistant
                    val intent = Intent(this, AIAssistantActivity::class.java)
                    startActivity(intent)
                    finish()
                } else {
                    // If anonymous fails, just go anyway
                    val intent = Intent(this, AIAssistantActivity::class.java)
                    startActivity(intent)
                    finish()
                }
            }
    }
}