package com.example.equilibrium

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class ChatAdapter(
    private val messages: List<ChatMessage>,
    private val onMessageClick: (ChatMessage) -> Unit
) : RecyclerView.Adapter<ChatAdapter.MessageViewHolder>() {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MessageViewHolder {
        // Create a simple text-based layout programmatically for now
        val textView = TextView(parent.context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setPadding(32, 16, 32, 16)
            textSize = 16f
        }
        return MessageViewHolder(textView)
    }

    override fun onBindViewHolder(holder: MessageViewHolder, position: Int) {
        holder.bind(messages[position], onMessageClick)
    }

    override fun getItemCount(): Int = messages.size

    class MessageViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val textView = itemView as TextView

        fun bind(message: ChatMessage, onMessageClick: (ChatMessage) -> Unit) {
            val displayText = when (message) {
                is UserMessage -> "👤 You: ${message.message}"
                is AIMessage -> "🤖 AI: ${message.message}"
                is WellnessCard -> "🏃‍♂️ Wellness: Steps: ${message.steps} | Calories: ${message.calories} | Water: ${message.hydrationGlasses}/${message.hydrationGoal}"
                is CommunicationCard -> "📧 Communication: ${message.count} unread | Latest: ${message.latestPreview}"
                is CalendarCard -> "📅 Calendar: ${message.eventTitle} at ${message.eventTime}"
                else -> "Message"
            }

            textView.text = displayText
            textView.setTextColor(
                when (message) {
                    is UserMessage -> 0xFF6200EE.toInt() // Purple for user
                    else -> 0xFF212121.toInt() // Dark gray for AI/cards
                }
            )

            itemView.setOnClickListener { onMessageClick(message) }
        }
    }
}