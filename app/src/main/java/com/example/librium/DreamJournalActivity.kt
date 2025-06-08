package com.example.librium

import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.ViewGroup  // ADD THIS IMPORT!
import android.graphics.drawable.GradientDrawable
import android.app.AlertDialog
import android.speech.tts.TextToSpeech
import java.text.SimpleDateFormat
import java.util.*
import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

class DreamJournalActivity : AppCompatActivity() {

    private lateinit var mainContainer: LinearLayout
    private lateinit var dreamsContainer: LinearLayout
    private lateinit var textToSpeech: TextToSpeech
    private lateinit var sharedPrefs: SharedPreferences
    private lateinit var geminiService: GeminiAIService
    private var dreams = mutableListOf<DreamEntry>()

    companion object {
        private const val PREFS_NAME = "DreamJournalPrefs"
        private const val DREAMS_KEY = "dreams"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize services
        geminiService = GeminiAIService(this)
        sharedPrefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        textToSpeech = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                textToSpeech.language = Locale.US
            }
        }

        // Load saved dreams
        loadDreams()

        // Create main layout
        mainContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0F172A"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        createHeader()
        createDreamsList()
        createFloatingActionButton()

        setContentView(mainContainer)
    }

    private fun createHeader() {
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(40, 60, 40, 40)
            background = GradientDrawable().apply {
                setColors(intArrayOf(Color.parseColor("#8B5CF6"), Color.parseColor("#6366F1")))
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
                cornerRadii = floatArrayOf(0f, 0f, 0f, 0f, 50f, 50f, 50f, 50f)
            }
        }

        val backButton = Button(this).apply {
            text = "←"
            textSize = 24f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = LinearLayout.LayoutParams(80, 80)
            setOnClickListener { finish() }
        }

        val title = TextView(this).apply {
            text = "🌙 Dream Journal"
            textSize = 28f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                marginStart = 20
            }
        }

        val statsText = TextView(this).apply {
            text = "${dreams.size} dreams"
            textSize = 16f
            setTextColor(Color.parseColor("#E2E8F0"))
        }

        header.addView(backButton)
        header.addView(title)
        header.addView(statsText)
        mainContainer.addView(header)
    }

    private fun createDreamsList() {
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        dreamsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 20, 40, 100)
        }

        updateDreamsList()
        scrollView.addView(dreamsContainer)
        mainContainer.addView(scrollView)
    }

    private fun updateDreamsList() {
        dreamsContainer.removeAllViews()

        if (dreams.isEmpty()) {
            val emptyState = TextView(this).apply {
                text = "✨ No dreams recorded yet\nTap + to add your first dream"
                textSize = 18f
                setTextColor(Color.parseColor("#94A3B8"))
                gravity = Gravity.CENTER
                setPadding(0, 100, 0, 0)
            }
            dreamsContainer.addView(emptyState)
        } else {
            dreams.forEach { dream ->
                createDreamCard(dream)
            }
        }
    }

    private fun createDreamCard(dream: DreamEntry) {
        val card = androidx.cardview.widget.CardView(this).apply {
            radius = 25f
            cardElevation = 8f
            setCardBackgroundColor(Color.parseColor("#1E293B"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 20
            }
        }

        val cardContent = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(30, 30, 30, 30)
        }

        // Date and mood
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val dateText = TextView(this).apply {
            text = SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(Date(dream.timestamp))
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8"))
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
        }

        val moodEmoji = TextView(this).apply {
            text = getMoodEmoji(dream.mood)
            textSize = 24f
        }

        headerRow.addView(dateText)
        headerRow.addView(moodEmoji)

        // Dream description
        val descriptionText = TextView(this).apply {
            text = dream.description
            textSize = 16f
            setTextColor(Color.WHITE)
            setPadding(0, 15, 0, 15)
            maxLines = 3
            ellipsize = android.text.TextUtils.TruncateAt.END
        }

        // Tags
        val tagsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.START
        }

        dream.tags.take(3).forEach { tag ->
            val tagView = TextView(this).apply {
                text = "#$tag"
                textSize = 12f
                setTextColor(Color.parseColor("#8B5CF6"))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#8B5CF620"))
                    cornerRadius = 15f
                }
                setPadding(15, 5, 15, 5)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    marginEnd = 10
                }
            }
            tagsContainer.addView(tagView)
        }

        // AI Analysis preview
        if (dream.analysis.isNotEmpty()) {
            val analysisPreview = TextView(this).apply {
                text = "✨ ${dream.analysis.take(100)}..."
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
                setTypeface(typeface, Typeface.ITALIC)
                setPadding(0, 15, 0, 0)
            }
            cardContent.addView(analysisPreview)
        }

        cardContent.addView(headerRow)
        cardContent.addView(descriptionText)
        cardContent.addView(tagsContainer)

        card.addView(cardContent)
        card.setOnClickListener {
            showDreamDetail(dream)
        }

        dreamsContainer.addView(card)
    }

    private fun createFloatingActionButton() {
        val fabContainer = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        val fab = Button(this).apply {
            text = "+"
            textSize = 32f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#8B5CF6"))
            }
            layoutParams = FrameLayout.LayoutParams(80, 80).apply {
                gravity = Gravity.BOTTOM or Gravity.END
                setMargins(0, 0, 40, 40)
            }
            elevation = 12f
            setOnClickListener {
                showAddDreamDialog()
            }
        }

        fabContainer.addView(fab)

        // Add the FAB container to the activity's root view
        val rootView = window.decorView.findViewById<ViewGroup>(android.R.id.content)
        rootView.addView(fabContainer)
    }

    private fun showAddDreamDialog() {
        val dialog = AlertDialog.Builder(this)
        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 40, 40, 40)
            setBackgroundColor(Color.parseColor("#1E293B"))
        }

        val title = TextView(this).apply {
            text = "🌙 Record Your Dream"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }

        val dreamInput = EditText(this).apply {
            hint = "Describe your dream..."
            setHintTextColor(Color.parseColor("#64748B"))
            setTextColor(Color.WHITE)
            textSize = 16f
            minLines = 5
            gravity = Gravity.TOP
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#334155"))
                cornerRadius = 20f
            }
            setPadding(20, 20, 20, 20)
        }

        val moodLabel = TextView(this).apply {
            text = "How did this dream make you feel?"
            textSize = 16f
            setTextColor(Color.parseColor("#94A3B8"))
            setPadding(0, 30, 0, 10)
        }

        val moodContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val moods = listOf(
            Pair("😌", "Peaceful"),
            Pair("😊", "Happy"),
            Pair("😰", "Anxious"),
            Pair("🤔", "Confused"),
            Pair("😮", "Surprised")
        )

        var selectedMood = "Peaceful"

        moods.forEach { (emoji, mood) ->
            val moodButton = TextView(this).apply {
                text = emoji
                textSize = 28f
                setPadding(15, 10, 15, 10)
                gravity = Gravity.CENTER
                setOnClickListener {
                    selectedMood = mood
                    // Update selection UI
                    (moodContainer.parent as LinearLayout).removeView(moodContainer)
                    showAddDreamDialog() // Refresh dialog
                }
            }
            moodContainer.addView(moodButton)
        }

        val saveButton = Button(this).apply {
            text = "💾 Save & Analyze"
            textSize = 18f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = GradientDrawable().apply {
                setColors(intArrayOf(Color.parseColor("#8B5CF6"), Color.parseColor("#6366F1")))
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
                cornerRadius = 25f
            }
            setPadding(40, 25, 40, 25)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 30
            }
            setOnClickListener {
                val dreamText = dreamInput.text.toString()
                if (dreamText.isNotEmpty()) {
                    saveDream(dreamText, selectedMood)
                    dialog.create().dismiss()
                }
            }
        }

        dialogView.addView(title)
        dialogView.addView(dreamInput)
        dialogView.addView(moodLabel)
        dialogView.addView(moodContainer)
        dialogView.addView(saveButton)

        dialog.setView(dialogView)
        dialog.show()
    }

    private fun saveDream(description: String, mood: String) {
        val loadingDialog = AlertDialog.Builder(this)
            .setMessage("✨ Analyzing your dream...")
            .setCancelable(false)
            .create()
        loadingDialog.show()

        lifecycleScope.launch {
            geminiService.generateDreamscapeResponse(description) { analysis ->
                val dream = DreamEntry(
                    id = System.currentTimeMillis(),
                    timestamp = System.currentTimeMillis(),
                    description = description,
                    mood = mood,
                    analysis = analysis,
                    tags = extractTags(description)
                )

                dreams.add(0, dream)
                saveDreamsToPrefs()
                updateDreamsList()
                loadingDialog.dismiss()

                Toast.makeText(this@DreamJournalActivity, "Dream saved! ✨", Toast.LENGTH_SHORT).show()

                // Speak the analysis
                textToSpeech.speak(analysis, TextToSpeech.QUEUE_FLUSH, null, null)
            }
        }
    }

    private fun extractTags(description: String): MutableList<String> {
        val commonDreamSymbols = listOf(
            "water", "flying", "falling", "chase", "lost", "late", "exam",
            "teeth", "death", "baby", "animal", "house", "car", "travel"
        )

        val tags = mutableListOf<String>()
        val words = description.toLowerCase().split(" ")

        commonDreamSymbols.forEach { symbol ->
            if (words.any { it.contains(symbol) }) {
                tags.add(symbol)
            }
        }

        return tags.take(5).toMutableList()
    }

    private fun showDreamDetail(dream: DreamEntry) {
        AlertDialog.Builder(this)
            .setTitle("🌙 Dream Details")
            .setMessage(buildString {
                appendLine("Date: ${SimpleDateFormat("MMMM d, yyyy", Locale.getDefault()).format(Date(dream.timestamp))}")
                appendLine("Mood: ${getMoodEmoji(dream.mood)} ${dream.mood}")
                appendLine("\nDream:")
                appendLine(dream.description)
                appendLine("\n✨ AI Analysis:")
                appendLine(dream.analysis)
                if (dream.tags.isNotEmpty()) {
                    appendLine("\nTags: ${dream.tags.joinToString(", ") { "#$it" }}")
                }
            })
            .setPositiveButton("Close") { dialog, _ -> dialog.dismiss() }
            .setNeutralButton("🔊 Listen") { _, _ ->
                textToSpeech.speak(dream.analysis, TextToSpeech.QUEUE_FLUSH, null, null)
            }
            .show()
    }

    private fun getMoodEmoji(mood: String): String {
        return when (mood) {
            "Peaceful" -> "😌"
            "Happy" -> "😊"
            "Anxious" -> "😰"
            "Confused" -> "🤔"
            "Surprised" -> "😮"
            else -> "😴"
        }
    }

    // Fixed JSON save/load methods - NO MORE GSON!
    private fun saveDreamsToPrefs() {
        val dreamsArray = JSONArray()

        dreams.forEach { dream ->
            val dreamObject = JSONObject().apply {
                put("id", dream.id)
                put("timestamp", dream.timestamp)
                put("description", dream.description)
                put("mood", dream.mood)
                put("analysis", dream.analysis)
                put("tags", JSONArray(dream.tags))
            }
            dreamsArray.put(dreamObject)
        }

        sharedPrefs.edit().putString(DREAMS_KEY, dreamsArray.toString()).apply()
    }

    private fun loadDreams() {
        val dreamsJson = sharedPrefs.getString(DREAMS_KEY, "[]") ?: "[]"
        dreams.clear()

        try {
            val dreamsArray = JSONArray(dreamsJson)

            for (i in 0 until dreamsArray.length()) {
                val dreamObject = dreamsArray.getJSONObject(i)

                val tagsList = mutableListOf<String>()
                val tagsArray = dreamObject.getJSONArray("tags")
                for (j in 0 until tagsArray.length()) {
                    tagsList.add(tagsArray.getString(j))
                }

                val dream = DreamEntry(
                    id = dreamObject.getLong("id"),
                    timestamp = dreamObject.getLong("timestamp"),
                    description = dreamObject.getString("description"),
                    mood = dreamObject.getString("mood"),
                    analysis = dreamObject.getString("analysis"),
                    tags = tagsList
                )

                dreams.add(dream)
            }

            dreams.sortByDescending { it.timestamp }

        } catch (e: Exception) {
            // If there's an error parsing, start fresh
            dreams.clear()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        textToSpeech.shutdown()
    }
}