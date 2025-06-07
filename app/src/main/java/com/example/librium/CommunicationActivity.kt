package com.example.librium

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.viewpager2.adapter.FragmentStateAdapter
import androidx.viewpager2.widget.ViewPager2
import com.google.android.material.tabs.TabLayout
import com.google.android.material.tabs.TabLayoutMediator

class CommunicationActivity : AppCompatActivity() {

    private lateinit var viewPager: ViewPager2
    private lateinit var tabLayout: TabLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_communication)

        // Set up the toolbar
        supportActionBar?.title = "Communication Hub"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        // Initialize views
        viewPager = findViewById(R.id.viewPager)
        tabLayout = findViewById(R.id.tabLayout)

        // Set up ViewPager with adapter
        val adapter = CommunicationPagerAdapter(this)
        viewPager.adapter = adapter

        // Connect TabLayout with ViewPager2
        TabLayoutMediator(tabLayout, viewPager) { tab, position ->
            tab.text = when (position) {
                0 -> "Texts"
                1 -> "Emails"
                2 -> "Contacts"
                else -> ""
            }

            // Add icons to tabs
            TabLayoutMediator(tabLayout, viewPager) { tab, position ->
                tab.text = when (position) {
                    0 -> "Texts"
                    1 -> "Emails"
                    2 -> "Contacts"
                    else -> ""
                }

                // REMOVE OR COMMENT OUT THE setIcon PART!
                // tab.setIcon(when (position) {
                //     0 -> R.drawable.ic_message
                //     1 -> R.drawable.ic_email
                //     2 -> R.drawable.ic_contacts
                //     else -> null
                // })
            }.attach()
        }.attach()

        // Check if we need to open a specific tab
        val selectedTab = intent.getStringExtra("selected_tab")
        when (selectedTab) {
            "texts" -> viewPager.setCurrentItem(0, false)
            "emails" -> viewPager.setCurrentItem(1, false)
            "contacts" -> viewPager.setCurrentItem(2, false)
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        onBackPressed()
        return true
    }

    // ViewPager adapter
    private inner class CommunicationPagerAdapter(fa: FragmentActivity) : FragmentStateAdapter(fa) {
        override fun getItemCount(): Int = 3

        override fun createFragment(position: Int): Fragment {
            return when (position) {
                0 -> TextsFragment()
                1 -> EmailsFragment()
                2 -> ContactsFragment()
                else -> TextsFragment()
            }
        }
    }
}

// Texts Fragment
class TextsFragment : Fragment(R.layout.fragment_texts) {
    override fun onViewCreated(view: android.view.View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // TODO: Set up RecyclerView for text messages
        // TODO: Implement SMS permissions and reading
        // TODO: Add floating action button for new message
    }
}

// Emails Fragment
class EmailsFragment : Fragment(R.layout.fragment_emails) {
    override fun onViewCreated(view: android.view.View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // TODO: Set up RecyclerView for emails
        // TODO: Implement Gmail API
        // TODO: Add pull-to-refresh
    }
}

// Contacts Fragment
class ContactsFragment : Fragment(R.layout.fragment_contacts) {
    override fun onViewCreated(view: android.view.View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // TODO: Set up RecyclerView for contacts
        // TODO: Implement contact permissions
        // TODO: Add search functionality
        // TODO: Add floating action button for new contact
    }
}