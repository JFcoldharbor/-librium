package com.example.librium

import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import java.util.*
import kotlin.random.Random

class DashboardActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create main layout
        val scrollView = ScrollView(this)
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
        }

        // Add title
        val titleText = TextView(this).apply {
            text = "Your Dashboard"
            textSize = 28f
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, 24)
        }
        mainLayout.addView(titleText)

        // Add statistics cards
        mainLayout.addView(createBalanceScoreCard())
        mainLayout.addView(createWeeklyStatsCard())
        mainLayout.addView(createProductivityCard())
        mainLayout.addView(createStreakCard())

        // Add back button
        val backButton = Button(this).apply {
            text = "← Back"
            setOnClickListener { finish() }
        }
        mainLayout.addView(backButton)

        scrollView.addView(mainLayout)
        setContentView(scrollView)
    }

    private fun createBalanceScoreCard(): CardView {
        return CardView(this).apply {
            radius = 12f
            cardElevation = 4f
            setCardBackgroundColor(Color.WHITE)

            val content = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(24, 24, 24, 24)

                val title = TextView(context).apply {
                    text = "Work-Life Balance Score"
                    textSize = 20f
                    setTextColor(Color.BLACK)
                }

                // Score display
                val scoreLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    setPadding(0, 16, 0, 16)

                    val scoreText = TextView(context).apply {
                        text = "78"
                        textSize = 48f
                        setTextColor(Color.parseColor("#4CAF50"))
                    }

                    val outOfText = TextView(context).apply {
                        text = "/100"
                        textSize = 24f
                        setTextColor(Color.GRAY)
                        setPadding(8, 20, 0, 0)
                    }

                    addView(scoreText)
                    addView(outOfText)
                }

                // Progress bar
                val progressBar = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
                    max = 100
                    progress = 78
                    progressDrawable.setColorFilter(Color.parseColor("#4CAF50"), android.graphics.PorterDuff.Mode.SRC_IN)
                }

                val improvementText = TextView(context).apply {
                    text = "↑ 5% improvement from last week"
                    textSize = 14f
                    setTextColor(Color.parseColor("#4CAF50"))
                    setPadding(0, 8, 0, 0)
                }

                addView(title)
                addView(scoreLayout)
                addView(progressBar)
                addView(improvementText)
            }

            addView(content)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
        }
    }

    private fun createWeeklyStatsCard(): CardView {
        return CardView(this).apply {
            radius = 12f
            cardElevation = 4f
            setCardBackgroundColor(Color.WHITE)

            val content = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(24, 24, 24, 24)

                val title = TextView(context).apply {
                    text = "This Week's Stats"
                    textSize = 20f
                    setTextColor(Color.BLACK)
                    setPadding(0, 0, 0, 16)
                }

                // Stats list
                val stats = listOf(
                    "⏰ Work Hours: 42 (target: 40)",
                    "🏃 Exercise: 4/5 days",
                    "😴 Avg Sleep: 7.2 hours",
                    "🧘 Meditation: 6/7 days",
                    "📱 Screen Time: 5.8 hrs/day"
                )

                addView(title)

                stats.forEach { stat ->
                    val statText = TextView(context).apply {
                        text = stat
                        textSize = 16f
                        setTextColor(Color.DKGRAY)
                        setPadding(0, 8, 0, 8)
                    }
                    addView(statText)
                }
            }

            addView(content)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
        }
    }

    private fun createProductivityCard(): CardView {
        return CardView(this).apply {
            radius = 12f
            cardElevation = 4f
            setCardBackgroundColor(Color.WHITE)

            val content = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(24, 24, 24, 24)

                val title = TextView(context).apply {
                    text = "Productivity Trends"
                    textSize = 20f
                    setTextColor(Color.BLACK)
                    setPadding(0, 0, 0, 16)
                }

                // Simple bar chart
                val chartLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        200
                    )

                    val days = listOf("Mon", "Tue", "Wed", "Thu", "Fri")
                    val values = listOf(85, 90, 75, 88, 92)

                    days.forEachIndexed { index, day ->
                        val dayLayout = LinearLayout(context).apply {
                            orientation = LinearLayout.VERTICAL
                            layoutParams = LinearLayout.LayoutParams(
                                0,
                                LinearLayout.LayoutParams.MATCH_PARENT,
                                1f
                            )
                            gravity = android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL

                            // Bar
                            val bar = View(context).apply {
                                layoutParams = LinearLayout.LayoutParams(
                                    40,
                                    (values[index] * 2)
                                )
                                setBackgroundColor(Color.parseColor("#2196F3"))
                            }

                            // Day label
                            val dayText = TextView(context).apply {
                                text = day
                                textSize = 12f
                                setPadding(0, 4, 0, 0)
                            }

                            addView(bar)
                            addView(dayText)
                        }
                        addView(dayLayout)
                    }
                }

                addView(title)
                addView(chartLayout)
            }

            addView(content)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
        }
    }

    private fun createStreakCard(): CardView {
        return CardView(this).apply {
            radius = 12f
            cardElevation = 4f
            setCardBackgroundColor(Color.parseColor("#FFE082"))

            val content = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(24, 24, 24, 24)
                gravity = android.view.Gravity.CENTER_VERTICAL

                val streakIcon = TextView(context).apply {
                    text = "🔥"
                    textSize = 40f
                    setPadding(0, 0, 16, 0)
                }

                val streakInfo = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL

                    val streakText = TextView(context).apply {
                        text = "7 Day Streak!"
                        textSize = 20f
                        setTextColor(Color.BLACK)
                    }

                    val streakDetail = TextView(context).apply {
                        text = "Keep logging your daily wellness"
                        textSize = 14f
                        setTextColor(Color.DKGRAY)
                    }

                    addView(streakText)
                    addView(streakDetail)
                }

                addView(streakIcon)
                addView(streakInfo)
            }

            addView(content)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
        }
    }
}