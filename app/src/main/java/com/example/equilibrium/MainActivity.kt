package com.example.equilibrium

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.google.firebase.auth.FirebaseAuth

class MainActivity : AppCompatActivity() {

    private lateinit var auth: FirebaseAuth

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set up FULL IMMERSIVE experience
        setupImmersiveMode()

        // Use your existing layout
        setContentView(R.layout.activity_main)

        // Handle system window insets (for notches, etc.)
        setupWindowInsets()

        // Initialize Firebase Auth
        auth = FirebaseAuth.getInstance()

        // Check if user is already signed in
        val currentUser = auth.currentUser
        if (currentUser != null) {
            navigateToAIAssistant()
            return
        }

        // Make entire screen clickable for testing (temporary)
        findViewById<android.view.View>(android.R.id.content).setOnClickListener {
            performTestLogin()
        }

        Toast.makeText(this, "🚀 Immersive Mode! Tap anywhere to test login!", Toast.LENGTH_LONG).show()
    }

    private fun setupImmersiveMode() {
        // Enable edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.apply {
                // Clear any existing flags
                clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
                clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)

                // Enable drawing behind system bars
                addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)

                // Make system bars transparent
                statusBarColor = Color.TRANSPARENT
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    navigationBarColor = Color.TRANSPARENT
                }
            }

            // Configure system bar appearance
            val windowInsetsController = WindowInsetsControllerCompat(window, window.decorView)

            // Use light icons for dark background
            windowInsetsController.isAppearanceLightStatusBars = false
            windowInsetsController.isAppearanceLightNavigationBars = false

            // Optional: Hide system bars completely for true immersive
            // windowInsetsController.hide(WindowInsetsCompat.Type.systemBars())
            // windowInsetsController.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    private fun setupWindowInsets() {
        // Handle window insets for devices with notches, etc.
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(android.R.id.content)) { view, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())

            // Add padding to avoid content being hidden behind system bars
            view.setPadding(
                systemBars.left,
                systemBars.top,
                systemBars.right,
                systemBars.bottom
            )

            insets
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Re-enable immersive mode when window gains focus
            setupImmersiveMode()
        }
    }

    private fun performTestLogin() {
        Toast.makeText(this, "🧪 Testing immersive login...", Toast.LENGTH_SHORT).show()

        auth.signInAnonymously()
            .addOnCompleteListener(this) { task ->
                if (task.isSuccessful) {
                    Toast.makeText(this, "✅ Immersive login successful!", Toast.LENGTH_SHORT).show()
                    navigateToAIAssistant()
                } else {
                    Toast.makeText(this, "❌ Login failed: ${task.exception?.message}", Toast.LENGTH_LONG).show()
                }
            }
    }

    private fun navigateToAIAssistant() {
        Toast.makeText(this, "🎉 Welcome to Immersive Equilibrium AI!", Toast.LENGTH_SHORT).show()

        try {
            val intent = Intent(this, AIAssistantActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            startActivity(intent)
            finish()
        } catch (e: Exception) {
            Log.e("MainActivity", "Navigation error: ${e.message}", e)
            Toast.makeText(this, "🔧 AI Assistant loading... Check activities!", Toast.LENGTH_LONG).show()
        }
    }
}