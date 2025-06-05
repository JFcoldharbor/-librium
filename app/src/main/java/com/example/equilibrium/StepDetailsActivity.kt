package com.example.equilibrium

import android.os.Bundle
import android.widget.ImageView
import androidx.appcompat.app.AppCompatActivity

class StepDetailsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_step_details)  // Uncomment this line

        // Hide the action bar
        supportActionBar?.hide()

        // Set up back button
        val btnBack = findViewById<ImageView>(R.id.btnBack)
        btnBack.setOnClickListener {
            finish()
        }
    }
}