package com.example.librium

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.cardview.widget.CardView
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.card.MaterialCardView
import java.text.SimpleDateFormat
import java.util.*

class ChatAdapter(
    private val messages: List<ChatMessage>,
    private val onCardClick: (ChatMessage) -> Unit
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    companion object {
        private const val VIEW_TYPE_USER_MESSAGE = 0
        private const val VIEW_TYPE_AI_MESSAGE = 1
        private const val VIEW_TYPE_WELLNESS_CARD = 2
        private const val VIEW_TYPE_EMAIL_CARD = 3
        private const val VIEW_TYPE_CALENDAR_CARD = 4
    }

    override fun getItemViewType(position: Int): Int {
        val message = messages[position]
        return when {
            message.isFromUser -> VIEW_TYPE_USER_MESSAGE
            message.messageType == MessageType.WELLNESS_CARD -> VIEW_TYPE_WELLNESS_CARD
            message.messageType == MessageType.EMAIL_CARD -> VIEW_TYPE_EMAIL_CARD
            message.messageType == MessageType.CALENDAR_CARD -> VIEW_TYPE_CALENDAR_CARD
            else -> VIEW_TYPE_AI_MESSAGE
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)

        return when (viewType) {
            VIEW_TYPE_USER_MESSAGE -> {
                val view = inflater.inflate(R.layout.item_chat_message_user, parent, false)
                UserMessageViewHolder(view)
            }
            VIEW_TYPE_AI_MESSAGE -> {
                val view = inflater.inflate(R.layout.item_chat_message_ai, parent, false)
                AIMessageViewHolder(view)
            }
            VIEW_TYPE_WELLNESS_CARD -> {
                val view = inflater.inflate(R.layout.item_wellness_card, parent, false)
                WellnessCardViewHolder(view)
            }
            VIEW_TYPE_EMAIL_CARD -> {
                val view = inflater.inflate(R.layout.item_email_card, parent, false)
                EmailCardViewHolder(view)
            }
            VIEW_TYPE_CALENDAR_CARD -> {
                val view = inflater.inflate(R.layout.item_calendar_card, parent, false)
                CalendarCardViewHolder(view)
            }
            else -> throw IllegalArgumentException("Invalid view type")
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val message = messages[position]

        when (holder) {
            is UserMessageViewHolder -> holder.bind(message)
            is AIMessageViewHolder -> holder.bind(message)
            is WellnessCardViewHolder -> holder.bind(message, onCardClick)
            is EmailCardViewHolder -> holder.bind(message, onCardClick)
            is CalendarCardViewHolder -> holder.bind(message, onCardClick)
        }
    }

    override fun getItemCount() = messages.size

    // ViewHolder for user messages
    inner class UserMessageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val messageText: TextView = itemView.findViewById(R.id.messageText)
        private val timeText: TextView = itemView.findViewById(R.id.timeText)

        fun bind(message: ChatMessage) {
            messageText.text = message.text
            timeText.text = formatTime(message.timestamp)
        }
    }

    // ViewHolder for AI messages
    inner class AIMessageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val messageText: TextView = itemView.findViewById(R.id.messageText)
        private val timeText: TextView = itemView.findViewById(R.id.timeText)

        fun bind(message: ChatMessage) {
            messageText.text = message.text
            timeText.text = formatTime(message.timestamp)
        }
    }

    // ViewHolder for wellness cards
    inner class WellnessCardViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val cardView: MaterialCardView = itemView.findViewById(R.id.wellnessCard)
        private val stepsText: TextView = itemView.findViewById(R.id.stepsText)
        private val caloriesText: TextView = itemView.findViewById(R.id.caloriesText)
        private val heartRateText: TextView = itemView.findViewById(R.id.heartRateText)
        private val messageText: TextView = itemView.findViewById(R.id.messageText)

        fun bind(message: ChatMessage, onClick: (ChatMessage) -> Unit) {
            val data = message.cardData as? WellnessCardData

            messageText.text = message.text

            data?.let {
                stepsText.text = "${it.steps} steps"
                caloriesText.text = "${it.calories} cal"
                heartRateText.text = "${it.heartRate} bpm"
            }

            cardView.setOnClickListener { onClick(message) }
        }
    }

    // ViewHolder for email cards
    inner class EmailCardViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val cardView: MaterialCardView = itemView.findViewById(R.id.emailCard)
        private val subjectText: TextView = itemView.findViewById(R.id.subjectText)
        private val senderText: TextView = itemView.findViewById(R.id.senderText)
        private val previewText: TextView = itemView.findViewById(R.id.previewText)
        private val messageText: TextView = itemView.findViewById(R.id.messageText)

        fun bind(message: ChatMessage, onClick: (ChatMessage) -> Unit) {
            val data = message.cardData as? EmailCardData

            messageText.text = message.text

            // For demo, show placeholder data if no real data
            if (data != null) {
                subjectText.text = data.subject
                senderText.text = data.sender
                previewText.text = data.preview
            } else {
                subjectText.text = "Team Meeting Tomorrow"
                senderText.text = "John Smith"
                previewText.text = "Hi team, just a reminder about our meeting..."
            }

            cardView.setOnClickListener { onClick(message) }
        }
    }

    // ViewHolder for calendar cards
    inner class CalendarCardViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val cardView: MaterialCardView = itemView.findViewById(R.id.calendarCard)
        private val eventTitle: TextView = itemView.findViewById(R.id.eventTitle)
        private val eventTime: TextView = itemView.findViewById(R.id.eventTime)
        private val eventLocation: TextView = itemView.findViewById(R.id.eventLocation)
        private val messageText: TextView = itemView.findViewById(R.id.messageText)

        fun bind(message: ChatMessage, onClick: (ChatMessage) -> Unit) {
            val data = message.cardData as? CalendarCardData

            messageText.text = message.text

            // For demo, show placeholder data if no real data
            if (data != null) {
                eventTitle.text = data.eventTitle
                eventTime.text = "${data.startTime} - ${data.endTime}"
                eventLocation.text = data.location ?: "No location"
            } else {
                eventTitle.text = "Daily Standup"
                eventTime.text = "10:00 AM - 10:30 AM"
                eventLocation.text = "Conference Room A"
            }

            cardView.setOnClickListener { onClick(message) }
        }
    }

    private fun formatTime(timestamp: Long): String {
        val sdf = SimpleDateFormat("h:mm a", Locale.getDefault())
        return sdf.format(Date(timestamp))
    }
}