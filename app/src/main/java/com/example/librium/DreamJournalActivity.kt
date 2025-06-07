package com.example.librium

import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
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

    // ... rest of your onCreate and other methods ...

    // Replace the Gson-based save/load methods with these:

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

    // ... rest of your methods stay the same ...
}