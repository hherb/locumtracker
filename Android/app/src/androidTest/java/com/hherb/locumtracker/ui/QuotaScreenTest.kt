package com.hherb.locumtracker.ui

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.hherb.locumtracker.ui.screens.quota.QuotaScreen
import com.hherb.locumtracker.ui.theme.LocumTrackerTheme
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.junit.Before
import org.junit.Rule
import org.junit.Test

@HiltAndroidTest
class QuotaScreenTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeRule = createComposeRule()

    @Before
    fun setup() {
        hiltRule.inject()
    }

    @Test
    fun testAppBar_showsTitle() {
        composeRule.setContent {
            LocumTrackerTheme {
                QuotaScreen()
            }
        }

        composeRule.onNodeWithText("FPS Quota").assertIsDisplayed()
    }

    @Test
    fun testEmptyState_showsCreateButton() {
        composeRule.setContent {
            LocumTrackerTheme {
                QuotaScreen()
            }
        }

        composeRule.onNodeWithText("No Quota Data").assertIsDisplayed()
        composeRule.onNodeWithText("Create Quota").assertIsDisplayed()
    }
}
