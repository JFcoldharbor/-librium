package com.example.librium

import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView

class CommunicationActivity : AppCompatActivity() {

    private lateinit var mainContainer: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create the BEST communication interface!
        mainContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#0F172A"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        setContentView(mainContainer)

        createHeader()
        createCommunicationCards()
    }

    private fun createHeader() {
        // Header with back button - Beautiful design!
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(40, 60, 40, 40)
        }

        val backButton = Button(this).apply {
            text = "←"
            textSize = 24f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener { finish() }
        }

        val title = TextView(this).apply {
            text = "💬 Communication Hub"
            textSize = 28f
            setTextColor(Color.parseColor("#0EA5E9"))
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                marginStart = 20
            }
        }

        header.addView(backButton)
        header.addView(title)
        mainContainer.addView(header)
    }

    private fun createCommunicationCards() {
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 0, 40, 40)
        }

        // Summary stats - The numbers that matter!
        createSummaryCard(container)

        // Recent messages - Stay connected!
        createRecentMessagesCard(container)

        // Important contacts - Your inner circle
        createImportantContactsCard(container)

        // Email summary - Never miss the important stuff
        createEmailSummaryCard(container)

        scrollView.addView(container)
        mainContainer.addView(scrollView)
    }

    private fun createSummaryCard(container: ViewGroup) {
        val card = CardView(this).apply {
            radius = 25f
            cardElevation = 8f
            setCardBackgroundColor(Color.parseColor("#1E293B"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 30
            }
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(30, 30, 30, 30)
        }

        val stats = listOf(
            Triple("📧", "12", "Unread"),
            Triple("💬", "5", "Messages"),
            Triple("📞", "3", "Missed Calls"),
            Triple("📅", "2", "Meetings")
        )

        stats.forEach { (icon, count, label) ->
            val statBox = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                )
            }

            val iconText = TextView(this).apply {
                text = icon
                textSize = 28f
                gravity = Gravity.CENTER
            }

            val countText = TextView(this).apply {
                text = count
                textSize = 32f
                setTextColor(Color.parseColor("#0EA5E9"))
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
            }

            val labelText = TextView(this).apply {
                text = label
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
                gravity = Gravity.CENTER
            }

            statBox.addView(iconText)
            statBox.addView(countText)
            statBox.addView(labelText)
            content.addView(statBox)
        }

        card.addView(content)
        container.addView(card)
    }

    private fun createRecentMessagesCard(container: ViewGroup) {
        val card = CardView(this).apply {
            radius = 25f
            cardElevation = 8f
            setCardBackgroundColor(Color.parseColor("#1E293B"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 30
            }
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(30, 30, 30, 30)
        }

        val title = TextView(this).apply {
            text = "Recent Messages"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 20)
        }

        content.addView(title)

        // Sample messages - Real conversations!
        val messages = listOf(
            Triple("Sarah Miller", "Great presentation today! 👏", "2 min ago"),
            Triple("Alex Chen", "Can we move the meeting to 3pm?", "15 min ago"),
            Triple("Team Chat", "John: Who's joining lunch?", "1 hour ago"),
            Triple("Mom", "Don't forget dinner on Sunday!", "2 hours ago")
        )

        messages.forEach { (sender, message, time) ->
            val messageItem = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#334155"))
                    cornerRadius = 20f
                }
                setPadding(20, 20, 20, 20)
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = 15
                }
            }

            // Avatar
            val avatar = TextView(this).apply {
                text = sender.split(" ").map { it.first() }.joinToString("")
                textSize = 18f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#0EA5E9"))
                    shape = GradientDrawable.OVAL
                }
                gravity = Gravity.CENTER
                width = 60
                height = 60
            }

            val textContent = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                ).apply {
                    marginStart = 20
                }
            }

            val senderText = TextView(this).apply {
                text = sender
                textSize = 16f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
            }

            val messageText = TextView(this).apply {
                text = message
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
                setPadding(0, 2, 0, 0)
            }

            textContent.addView(senderText)
            textContent.addView(messageText)

            val timeText = TextView(this).apply {
                text = time
                textSize = 12f
                setTextColor(Color.parseColor("#64748B"))
            }

            messageItem.addView(avatar)
            messageItem.addView(textContent)
            messageItem.addView(timeText)
            content.addView(messageItem)
        }

        card.addView(content)
        container.addView(card)
    }

    private fun createImportantContactsCard(container: ViewGroup) {
        val card = CardView(this).apply {
            radius = 25f
            cardElevation = 8f
            setCardBackgroundColor(Color.parseColor("#1E293B"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 30
            }
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(30, 30, 30, 30)
        }

        val title = TextView(this).apply {
            text = "Important Contacts"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 20)
        }

        content.addView(title)

        // VIP contacts grid - The people who matter!
        val contactsGrid = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        val contacts = listOf(
            Pair("👨‍💼", "Boss"),
            Pair("👥", "Team"),
            Pair("🏠", "Family"),
            Pair("⭐", "VIP")
        )

        contacts.forEach { (emoji, label) ->
            val contactButton = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#334155"))
                    cornerRadius = 20f
                }
                setPadding(20, 20, 20, 20)
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                ).apply {
                    setMargins(5, 0, 5, 0)
                }
                isClickable = true
                setOnClickListener {
                    Toast.makeText(context, "Opening $label contacts", Toast.LENGTH_SHORT).show()
                }
            }

            val emojiText = TextView(this).apply {
                text = emoji
                textSize = 32f
                gravity = Gravity.CENTER
            }

            val labelText = TextView(this).apply {
                text = label
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
                gravity = Gravity.CENTER
                setPadding(0, 10, 0, 0)
            }

            contactButton.addView(emojiText)
            contactButton.addView(labelText)
            contactsGrid.addView(contactButton)
        }

        content.addView(contactsGrid)
        card.addView(content)
        container.addView(card)
    }

    private fun createEmailSummaryCard(container: ViewGroup) {
        val card = CardView(this).apply {
            radius = 25f
            cardElevation = 8f
            setCardBackgroundColor(Color.parseColor("#1E293B"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 30
            }
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(30, 30, 30, 30)
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val title = TextView(this).apply {
            text = "📧 Email Summary"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
        }

        val badge = TextView(this).apply {
            text = "12 new"
            textSize = 14f
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#EF4444"))
                cornerRadius = 15f
            }
            setPadding(20, 8, 20, 8)
        }

        header.addView(title)
        header.addView(badge)
        content.addView(header)

        // Email categories - Smart organization!
        val categories = listOf(
            Triple("🔥 Urgent", "3 emails", Color.parseColor("#EF4444")),
            Triple("💼 Work", "5 emails", Color.parseColor("#3B82F6")),
            Triple("📊 Reports", "2 emails", Color.parseColor("#10B981")),
            Triple("📰 Newsletters", "2 emails", Color.parseColor("#8B5CF6"))
        )

        val categoriesContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 20, 0, 0)
        }

        categories.forEach { (category, count, color) ->
            val categoryItem = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, 10, 0, 10)
            }

            // Fixed: Added the missing dot variable
            val dot = TextView(this).apply {
                text = "●"
                textSize = 16f
                setTextColor(color)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    marginEnd = 15
                }
            }

            val categoryText = TextView(this).apply {
                text = category
                textSize = 16f
                setTextColor(Color.WHITE)
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                )
            }

            val countText = TextView(this).apply {
                text = count
                textSize = 14f
                setTextColor(Color.parseColor("#94A3B8"))
            }

            categoryItem.addView(dot)
            categoryItem.addView(categoryText)
            categoryItem.addView(countText)
            categoriesContainer.addView(categoryItem)
        }

        content.addView(categoriesContainer)

        // AI summary - The smartest email assistant!
        val aiSummary = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            background = GradientDrawable().apply {
                setColors(intArrayOf(Color.parseColor("#0EA5E9"), Color.parseColor("#3B82F6")))
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
                cornerRadius = 20f
            }
            setPadding(25, 20, 25, 20)
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 20
            }
        }

        val aiIcon = TextView(this).apply {
            text = "🤖"
            textSize = 24f
            setPadding(0, 0, 15, 0)
        }

        val aiText = TextView(this).apply {
            text = "AI Summary: 3 urgent emails need attention, 2 meetings confirmed"
            textSize = 14f
            setTextColor(Color.WHITE)
        }

        aiSummary.addView(aiIcon)
        aiSummary.addView(aiText)
        content.addView(aiSummary)

        card.addView(content)
        container.addView(card)
    }
}

// The most organized communication hub - nobody communicates better! 📱💬