package com.example.librium

import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.graphics.drawable.GradientDrawable

class CommunicationActivity : AppCompatActivity() {

    private lateinit var contentContainer: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Main layout
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF0F172A.toInt())
        }

        // Header with back button
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(24, 24, 24, 16)
        }

        val backButton = Button(this).apply {
            text = "← Back"
            setOnClickListener { finish() }
        }
        header.addView(backButton)

        val title = TextView(this).apply {
            text = "👥 Contacts"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(16, 0, 0, 0)
        }
        header.addView(title)

        mainLayout.addView(header)

        // Content container
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        contentContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 0, 24, 24)
        }

        scrollView.addView(contentContainer)
        mainLayout.addView(scrollView)

        setContentView(mainLayout)

        // Show contacts
        showContacts()
    }

    private fun showContacts() {
        val contacts = listOf(
            Contact("Sarah Johnson", "sarah@example.com", "Team Lead", true),
            Contact("Michael Chen", "michael@example.com", "Designer", true),
            Contact("Emily Davis", "emily@example.com", "Product Manager", false),
            Contact("John Smith", "john@example.com", "Developer", true),
            Contact("Lisa Anderson", "lisa@example.com", "Marketing", false),
            Contact("David Wilson", "david@example.com", "Sales", true),
            Contact("Amanda Brown", "amanda@example.com", "HR Manager", false)
        )

        // Summary card
        val summaryCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
                colors = intArrayOf(0xFF9C27B0.toInt(), 0xFF3B82F6.toInt())
                cornerRadius = 20f
            }
            setPadding(24, 24, 24, 24)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, 16)
            }
        }

        val favoriteCount = contacts.count { it.isFavorite }
        summaryCard.addView(TextView(this).apply {
            text = "👥 ${contacts.size} contacts"
            textSize = 20f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
        })

        summaryCard.addView(TextView(this).apply {
            text = "⭐ $favoriteCount favorites"
            textSize = 14f
            setTextColor(0xFFFFFFFF.toInt())
            setPadding(0, 4, 0, 0)
        })

        contentContainer.addView(summaryCard)

        // Quick actions
        val quickActions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, 16)
        }

        quickActions.addView(createQuickActionButton("➕ Add") {
            Toast.makeText(this, "Add contact feature coming soon!", Toast.LENGTH_SHORT).show()
        })

        quickActions.addView(createQuickActionButton("🔍 Search") {
            Toast.makeText(this, "Search feature coming soon!", Toast.LENGTH_SHORT).show()
        })

        contentContainer.addView(quickActions)

        // Contact list
        contacts.forEach { contact ->
            val contactCard = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setBackgroundColor(0xFF1E293B.toInt())
                setPadding(20, 20, 20, 20)
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(0, 0, 0, 12)
                }
            }

            // Avatar
            val avatar = TextView(this).apply {
                text = contact.name.split(" ").map { it.first() }.joinToString("")
                textSize = 18f
                setTextColor(Color.WHITE)
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(if (contact.isFavorite) 0xFFFF5722.toInt() else 0xFF9C27B0.toInt())
                }
                gravity = Gravity.CENTER
                setPadding(24, 20, 24, 20)
            }
            contactCard.addView(avatar)

            // Details
            val detailsLayout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(16, 0, 0, 0)
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                )
            }

            detailsLayout.addView(TextView(this).apply {
                text = contact.name + if (contact.isFavorite) " ⭐" else ""
                textSize = 18f
                setTextColor(Color.WHITE)
                typeface = Typeface.DEFAULT_BOLD
            })

            detailsLayout.addView(TextView(this).apply {
                text = contact.role
                textSize = 14f
                setTextColor(0xFFFF5722.toInt())
            })

            contactCard.addView(detailsLayout)

            // Call button
            val callButton = Button(this).apply {
                text = "📞"
                textSize = 20f
                setBackgroundColor(Color.TRANSPARENT)
                setOnClickListener {
                    Toast.makeText(context, "Calling ${contact.name}...", Toast.LENGTH_SHORT).show()
                }
            }
            contactCard.addView(callButton)

            contactCard.setOnClickListener {
                Toast.makeText(this, "Opening ${contact.name}'s profile", Toast.LENGTH_SHORT).show()
            }

            contentContainer.addView(contactCard)
        }
    }

    private fun createQuickActionButton(text: String, onClick: () -> Unit): Button {
        return Button(this).apply {
            this.text = text
            setBackgroundColor(0xFF334155.toInt())
            setTextColor(Color.WHITE)
            setPadding(20, 12, 20, 12)
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                setMargins(0, 0, 8, 0)
            }
            setOnClickListener { onClick() }
        }
    }

    data class Contact(
        val name: String,
        val email: String,
        val role: String,
        val isFavorite: Boolean
    )
}