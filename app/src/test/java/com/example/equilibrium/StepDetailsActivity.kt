private fun setupClickableCards() {
    // Steps Card - try with full package name
    val stepsCard = findViewById<CardView>(R.id.cardSteps)
    stepsCard.setOnClickListener {
        try {
            val intent = Intent(this, com.example.librium.`GeminiAiService.kt`::class.java)
            startActivity(intent)
        } catch (e: Exception) {
            Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }
}